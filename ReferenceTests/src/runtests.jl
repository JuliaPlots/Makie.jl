
function extract_frames(video, frame_folder)
    path = joinpath(frame_folder, "frames%04d.png")
    FFMPEG.ffmpeg_exe(`-loglevel quiet -i $video -y $path`)
end


function get_frames(a, b)
    return (get_frames(a), get_frames(b))
end

function get_frames(video)
    mktempdir() do folder
        afolder = joinpath(folder, "a")
        mkpath(afolder)
        extract_frames(video, afolder)
        aframes = joinpath.(afolder, readdir(afolder))
        if length(aframes) > 10
            # we don't want to compare too many frames since it's time costly
            # so we just compare 10 random frames if more than 10
            samples = range(1, stop=length(aframes), length=10)
            istep = round(Int, length(aframes) / 10)
            samples = 1:istep:length(aframes)
            aframes = aframes[samples]
        end
        return load.(aframes)
    end
end

function compare_media(a::Matrix, b::Matrix; sigma=[1,1])
    Images.test_approx_eq_sigma_eps(a, b, sigma, Inf)
end

function compare_media(a, b; sigma=[1,1])
    file, ext = splitext(a)
    if ext in (".png", ".jpg", ".jpeg", ".JPEG", ".JPG")
        imga = load(a)
        imgb = load(b)
        if size(imga) != size(imgb)
            @warn "images don't have the same size, difference will be Inf"
            return Inf
        end
        conv(x) = convert(Matrix{RGBf}, x)
        return compare_media(conv(imga), conv(imgb), sigma=sigma)
    elseif ext in (".mp4", ".gif")
        aframes, bframes = get_frames(a, b)
        return mean(compare_media.(aframes, bframes; sigma=sigma))
    else
        error("Unknown media extension: $ext")
    end
end

function compare(test_files::Vector{String}, reference_dir::String; o_refdir=reference_dir, missing_refimages=String[], scores=Dict{String,Float64}())
    for test_path in test_files
        ref_path = joinpath(reference_dir, basename(test_path))
        if isdir(test_path)
            if !isdir(ref_path)
                push!(missing_refimages, test_path)
            else
                compare(joinpath.(test_path, readdir(test_path)), ref_path; o_refdir=reference_dir, missing_refimages=missing_refimages, scores=scores)
            end
        elseif isfile(test_path)
            if !isfile(ref_path)
                push!(missing_refimages, test_path)
            elseif endswith(test_path, ".html")
                # ignore
            else
                diff = compare_media(test_path, ref_path)
                name = relpath(ref_path, o_refdir)
                @info(@sprintf "%1.4f == %s\n" diff name)
                scores[name] = diff
            end
        end
    end
    return missing_refimages, scores
end

function run_reference_tests(db, recording_folder; difference=0.03, ref_images = download_refimages())
    record_tests(db, recording_dir=recording_folder)
    missing_files, scores = compare(joinpath.(recording_folder, readdir(recording_folder)), ref_images)
    if !isempty(missing_files)
        @warn("""
        #################################
        Newly recorded files found! The tests will pass, but uploading new reference images is required!
        #################################
        """)
    end
    open(joinpath(recording_folder, "new_files.html"), "w") do io
        for filename in missing_files
            println(io, "<h1> $(basename(filename)) </h1>")
            println(io, """
                <div>
                    $(embed_media(filename))
                </div>
            """)
        end
    end

    generate_test_summary(joinpath(recording_folder, "preview.html"), recording_folder, ref_images, scores)
    reference_tests(scores; difference=difference)
end

function reference_tests(scores; difference=0.03)
    @testset "Reference Image Tests" begin
        @testset "$name" for (name, score) in scores
            @test score < difference
        end
        return scores
    end
end

function record_tests(db=load_database(); recording_dir=basedir("recorded"))
    recorded_files = String[]
    @testset "Record tests" begin
        rm(recording_dir, recursive=true, force=true)
        mkdir(recording_dir)
        Makie.inline!(true)
        no_backend = Makie.current_backend[] === missing
        for (source_location, entry) in db
            try
                Makie.set_theme!(resolution=(500, 500))
                # we currently can't record anything without a backend!
                if no_backend && ((:Record in entry.used_functions) || (:Stepper in entry.used_functions))
                    continue
                end
                RNG.seed_rng!()
                result = Base.invokelatest(entry.func)
                # only save if we have a backend for saving
                uname = unique_name(entry)
                if !no_backend
                    save_result(joinpath(recording_dir, uname), result)
                end
                push!(recorded_files, uname)
                @info("Tested: $(nice_title(entry))")
                @test true
            catch e
                @info("Test: $(nice_title(entry)) didn't pass")
                @test false
                Base.showerror(stderr, e)
                Base.show_backtrace(stderr, Base.catch_backtrace())
            end
        end
    end
    return recorded_files, recording_dir
end

function run_tests(db=load_database(); ref_images = ReferenceTests.download_refimages(),
                    recording_dir=joinpath(@__DIR__, "..", "recorded"), difference=0.03)
    files, dir = record_tests(db, recording_dir=recording_dir)
    reference_tests(recording_dir, ref_images=ref_images, difference=difference)
end
