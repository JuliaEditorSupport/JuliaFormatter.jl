module ConfigTests

using JuliaFormatter: format, CONFIG_FILE_NAME
using Test

@testset ".JuliaFormatter.toml config" begin
    config2 = "indent = 2"
    config4 = "indent = 4"
    before = "begin rand() end\n"
    after2 = "begin\n  rand()\nend\n"
    after4 = "begin\n    rand()\nend\n"

    @testset "basic configuration" begin
        # ├─ .JuliaFormatter.toml (config2)
        # └─ code.jl (before -> after2)
        mktempdir() do dir
            code_path = joinpath(dir, "code.jl")
            write(joinpath(dir, CONFIG_FILE_NAME), config2)
            write(code_path, before)

            @test format(code_path) == false
            @test read(code_path, String) == after2
        end
    end

    @testset "upward config search" begin
        # ├─ .JuliaFormatter.toml (config2)
        # └─ sub
        #    ├─ sub_code.jl (before -> after2)
        #    └─ subsub
        #       └─ subsub_code.jl (before -> after2)
        mktempdir() do dir
            sub_dir = mkdir(joinpath(dir, "sub"))
            subsub_dir = mkdir(joinpath(sub_dir, "sub"))
            sub_code_path = joinpath(sub_dir, "sub_code.jl")
            subsub_code_path = joinpath(subsub_dir, "sub_code.jl")
            write(joinpath(dir, CONFIG_FILE_NAME), config2)
            write(sub_code_path, before)
            write(subsub_code_path, before)

            @test format(sub_code_path) == false
            @test read(sub_code_path, String) == after2
            @test format(subsub_code_path) == false
            @test read(subsub_code_path, String) == after2
            @test format(sub_code_path) == true
            @test format(subsub_code_path) == true
        end
    end

    @testset "basic directory walk" begin
        # ├─ .JuliaFormatter.toml (config2)
        # ├─ code.jl (before -> after2)
        # └─ sub
        #    └─ sub_code.jl (before -> after2)
        mktempdir() do dir
            sub_dir = mkdir(joinpath(dir, "sub"))
            code_path = joinpath(dir, "code.jl")
            sub_code_path = joinpath(sub_dir, "sub_code.jl")
            write(joinpath(dir, CONFIG_FILE_NAME), config2)
            write(code_path, before)
            write(sub_code_path, before)

            @test format(dir) == false
            @test read(code_path, String) == after2
            @test read(sub_code_path, String) == after2
            @test format(dir) == true
        end
    end

    @testset "directory walk with nested configs" begin
        # ├─ .JuliaFormatter.toml (config2)
        # ├─ code.jl (before -> after2)
        # ├─ sub1
        # │  ├─ .JuliaFormatter.toml (config4)
        # │  └─ sub_code1.jl (before -> after4)
        # └─ sub2
        #    └─ sub_code2.jl (before -> after2)
        mktempdir() do dir
            sub1_dir = mkdir(joinpath(dir, "sub1"))
            sub2_dir = mkdir(joinpath(dir, "sub2"))
            code_path = joinpath(dir, "code.jl")
            sub_code1_path = joinpath(sub1_dir, "sub_code1.jl")
            sub_code2_path = joinpath(sub2_dir, "sub_code2.jl")
            write(joinpath(dir, CONFIG_FILE_NAME), config2)
            write(joinpath(sub1_dir, CONFIG_FILE_NAME), config4)
            write(code_path, before)
            write(sub_code1_path, before)
            write(sub_code2_path, before)

            @test format(dir) == false
            @test read(code_path, String) == after2
            @test read(sub_code1_path, String) == after4
            @test read(sub_code2_path, String) == after2
            @test format(dir) == true
        end
    end

    @testset "per-file format with nested configs" begin
        # Same layout as the directory walk test, but format() each file individually.
        # ├─ .JuliaFormatter.toml (config2)
        # ├─ code.jl (before -> after2)
        # ├─ sub1
        # │  ├─ .JuliaFormatter.toml (config4)
        # │  └─ sub_code1.jl (before -> after4)
        # └─ sub2
        #    └─ sub_code2.jl (before -> after2)
        mktempdir() do dir
            sub1_dir = mkdir(joinpath(dir, "sub1"))
            sub2_dir = mkdir(joinpath(dir, "sub2"))
            code_path = joinpath(dir, "code.jl")
            sub_code1_path = joinpath(sub1_dir, "sub_code1.jl")
            sub_code2_path = joinpath(sub2_dir, "sub_code2.jl")
            write(joinpath(dir, CONFIG_FILE_NAME), config2)
            write(joinpath(sub1_dir, CONFIG_FILE_NAME), config4)
            write(code_path, before)
            write(sub_code1_path, before)
            write(sub_code2_path, before)

            # Root file picks up root config (indent=2)
            @test format(code_path) == false
            @test read(code_path, String) == after2
            # sub1 file picks up sub1 config (indent=4), not root
            @test format(sub_code1_path) == false
            @test read(sub_code1_path, String) == after4
            # sub2 file has no local config, walks up to root (indent=2)
            @test format(sub_code2_path) == false
            @test read(sub_code2_path, String) == after2
            # Idempotence
            @test format(code_path) == true
            @test format(sub_code1_path) == true
            @test format(sub_code2_path) == true
        end
    end

    @testset "directory walk with nested configs toplevel" begin
        # Same as "directory walk with nested configs" except format from within the
        # top level directory, i.e. `format(".")`
        mktempdir() do dir
            sub1_dir = mkdir(joinpath(dir, "sub1"))
            sub2_dir = mkdir(joinpath(dir, "sub2"))
            code_path = joinpath(dir, "code.jl")
            sub_code1_path = joinpath(sub1_dir, "sub_code1.jl")
            sub_code2_path = joinpath(sub2_dir, "sub_code2.jl")
            write(joinpath(dir, CONFIG_FILE_NAME), config2)
            write(joinpath(sub1_dir, CONFIG_FILE_NAME), config4)
            write(code_path, before)
            write(sub_code1_path, before)
            write(sub_code2_path, before)

            cd(dir) do
                @test format(".") == false
                @test read(code_path, String) == after2
                @test read(sub_code1_path, String) == after4
                @test read(sub_code2_path, String) == after2
                @test format(".") == true
            end
        end
    end

    @testset "markdown formatting" begin
        config2 = """
        indent = 2
        format_markdown = true
        """

        before = """
        # hello world

        ```julia
        begin body end
        ```
        - a
        -             b
        """
        after2 = """
        # hello world

        ```julia
        begin
          body
        end
        ```

          - a
          -             b
        """
        # ├─ .JuliaFormatter.toml (config2)
        # └─ file.md (before -> after2)
        mktempdir() do dir
            md_path = joinpath(dir, "file.md")
            write(joinpath(dir, CONFIG_FILE_NAME), config2)
            write(md_path, before)

            @test format(md_path) == false
            @test read(md_path, String) == after2
        end
    end

    @testset "jmd formatting" begin
        config2 = """
        indent = 2
        format_markdown = true
        """

        before = """
        ---
        title: Test file
        author: JuliaFormatter
        ---

        # hello world

        ```julia
        begin body end
        ```
        - a
        -             b
        """
        after2 = """
        ---
        title: Test file
        author: JuliaFormatter
        ---

        # hello world

        ```julia
        begin
          body
        end
        ```

          - a
          -             b
        """
        # ├─ .JuliaFormatter.toml (config2)
        # └─ file.jmd (before -> after2)
        mktempdir() do dir
            md_path = joinpath(dir, "file.jmd")
            write(joinpath(dir, CONFIG_FILE_NAME), config2)
            write(md_path, before)

            @test format(md_path) == false
            @test read(md_path, String) == after2
        end
    end

    @testset "qmd formatting" begin
        config2 = """
        indent = 2
        format_markdown = true
        """

        before = """
        ---
        title: Test file
        author: JuliaFormatter
        ---

        # hello world

        ```{julia}
        begin body end
        ```
        - a
        -             b
        """
        after2 = """
        ---
        title: Test file
        author: JuliaFormatter
        ---

        # hello world

        ```{julia}
        begin
          body
        end
        ```

          - a
          -             b
        """
        # ├─ .JuliaFormatter.toml (config2)
        # └─ file.qmd (before -> after2)
        mktempdir() do dir
            md_path = joinpath(dir, "file.qmd")
            write(joinpath(dir, CONFIG_FILE_NAME), config2)
            write(md_path, before)

            @test format(md_path) == false
            @test read(md_path, String) == after2
        end
    end

    @testset "trailing_comma = nothing" begin
        config_trailing_comma_nothing = """
        trailing_comma = "nothing"
        """

        code_trailing_comma = """
        const A_SET_OF_SYMBOLS_WITH_TRAILING_COMMA = Set([
            :accesses, :allowedtypes, :connector, :digits, :equals, :expand,
            :ignores, :sigdigits, :sort, :val_to_string,
        ])
        const A_SET_OF_SYMBOLS_WITHOUT_TRAILING_COMMA = Set([
            :accesses, :allowedtypes, :connector, :digits, :equals, :expand,
            :ignores, :sigdigits, :sort, :val_to_string
        ])
        """
        code_trailing_comma_after = """
        const A_SET_OF_SYMBOLS_WITH_TRAILING_COMMA = Set([
            :accesses,
            :allowedtypes,
            :connector,
            :digits,
            :equals,
            :expand,
            :ignores,
            :sigdigits,
            :sort,
            :val_to_string,
        ])
        const A_SET_OF_SYMBOLS_WITHOUT_TRAILING_COMMA = Set([
            :accesses,
            :allowedtypes,
            :connector,
            :digits,
            :equals,
            :expand,
            :ignores,
            :sigdigits,
            :sort,
            :val_to_string
        ])
        """
        # ├─ .JuliaFormatter.toml (config_trailing_comma_nothing)
        # └─ code.jl (code_trailing_comma -> code_trailing_comma_after)
        mktempdir() do dir
            code_path = joinpath(dir, "code.jl")
            write(joinpath(dir, CONFIG_FILE_NAME), config_trailing_comma_nothing)
            write(code_path, code_trailing_comma)

            @test format(code_path) == false
            @test read(code_path, String) == code_trailing_comma_after
        end
    end

    @testset "always_for_in = nothing" begin
        config_always_for_in_nothing = """
        always_for_in = "nothing"
        """
        code_always_for_in = """
        for i in 1:10
                for j = 1:10
            end
        end
        """
        code_always_for_in_after = """
        for i in 1:10
            for j = 1:10
            end
        end
        """

        # ├─ .JuliaFormatter.toml (always_for_in_nothing)
        # └─ code.jl (code_always_for_in -> code_always_for_in_after)
        mktempdir() do dir
            code_path = joinpath(dir, "code.jl")
            write(joinpath(dir, CONFIG_FILE_NAME), config_always_for_in_nothing)
            write(code_path, code_always_for_in)

            @test format(code_path) == false
            @test read(code_path, String) == code_always_for_in_after
        end
    end

    @testset "ignore" begin
        unformatted_text = "( )"
        tobeignored = (
            "b.jl",
            "ignored_directory/a.jl",
            "other_directory/ignored_directory/a.jl",
            "other_directory/directory/b.jl",
            "third_directory/a.jl",
            "third_directory/ignored_directory/a.jl",
        )
        nottobeignored = (
            "a.jl",
            "other_directory/a.jl",
            "other_directory/directory/a.jl",
            "third_directory/b.jl",
            "third_directory/ignored_directory/b.jl",
        )
        mktempdir() do sandbox_dir
            cp("files/ignore", sandbox_dir; force = true)
            @test format(sandbox_dir) == false
            @test format(sandbox_dir) == true
            for file in tobeignored
                code_path = joinpath(sandbox_dir, file)
                @test startswith(read(code_path, String), unformatted_text)
            end
            for file in nottobeignored
                code_path = joinpath(sandbox_dir, file)
                @test !startswith(read(code_path, String), unformatted_text)
            end
        end
    end
end

end
