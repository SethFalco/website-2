module Git
  class Exercise
    extend Mandate::Memoize
    extend Mandate::InitializerInjector
    extend Git::HasGitFilepaths

    delegate :head_sha, :lookup_commit, :head_commit, to: :repo

    git_filepaths instructions: ".docs/instructions.md",
      instructions_append: ".docs/instructions.append.md",
      introduction: ".docs/introduction.md",
      introduction_append: ".docs/introduction.append.md",
      hints: ".docs/hints.md",
      config: ".meta/config.json"

    SPECIAL_FILEPATHS = {
      config: '.exercism/config.json',
      readme: 'README.md',
      hints: 'HINTS.md',
      help: 'HELP.md'
    }.freeze

    def self.for_solution(solution)
      new(
        solution.git_slug,
        solution.git_type,
        solution.git_sha,
        repo_url: solution.track.repo_url
      )
    end

    def initialize(exercise_slug, exercise_type, git_sha = "HEAD", repo_url: nil, repo: nil)
      @repo = repo || Repository.new(repo_url: repo_url)
      @exercise_slug = exercise_slug
      @exercise_type = exercise_type
      @git_sha = git_sha
    end

    def synced_git_sha
      commit.oid
    end

    def valid_submission_filepath?(filepath)
      return false if filepath.match?(%r{[^a-zA-Z0-9_./-]})
      return false if filepath.starts_with?(".meta")
      return false if filepath.starts_with?(".docs")
      return false if filepath.starts_with?(".exercism")

      # We don't want to let students override the test files. However, some languages
      # have solutions and tests in the same file so we need the second guard for that.
      return false if test_filepaths.include?(filepath) && !solution_filepaths.include?(filepath)

      true
    end

    memoize
    def authors
      config[:authors].to_a
    end

    memoize
    def contributors
      config[:contributors].to_a
    end

    memoize
    def source
      config[:source]
    end

    memoize
    def source_url
      config[:source_url]
    end

    memoize
    def blurb
      config[:blurb]
    end

    memoize
    def icon_name
      config[:icon] || exercise_slug.to_s
    end

    memoize
    def has_test_runner?
      config.fetch(:test_runner, true)
    end

    memoize
    def solution_filepaths
      config.dig(:files, :solution).to_a
    end

    memoize
    def test_filepaths
      config.dig(:files, :test).to_a
    end

    memoize
    def editor_filepaths
      config.dig(:files, :editor).to_a
    end

    memoize
    def exemplar_filepaths
      config.dig(:files, :exemplar).to_a
    end

    memoize
    def example_filepaths
      config.dig(:files, :example).to_a
    end

    memoize
    def exemplar_files
      exemplar_filepaths.index_with do |filepath|
        read_file_blob(filepath)
      end
    rescue StandardError
      {}
    end

    memoize
    def example_files
      example_filepaths.index_with do |filepath|
        read_file_blob(filepath)
      end
    rescue StandardError
      {}
    end

    def tests
      test_filepaths.index_with do |filepath|
        read_file_blob(filepath)
      end
    rescue StandardError
      {}
    end

    # Files that should be transported
    # to a user for use in the editor.
    memoize
    def files_for_editor
      files = {}

      solution_filepaths.each do |filepath|
        files[filepath] = { type: :exercise, content: read_file_blob(filepath) }
      end

      editor_filepaths.each do |filepath|
        files[filepath] = { type: :readonly, content: read_file_blob(filepath) }
      end

      files
    rescue StandardError
      {}
    end

    # This includes meta files
    memoize
    def tooling_files
      tooling_filepaths.each.with_object({}) do |filepath, hash|
        hash[filepath] = read_file_blob(filepath)
      end
    end

    # This includes meta files
    memoize
    def tooling_filepaths
      filepaths
    end

    # This includes meta files
    memoize
    def tooling_absolute_filepaths
      tooling_filepaths.map { |filepath| absolute_filepath(filepath) }
    end

    memoize
    def important_files
      important_filepaths.each.with_object({}) do |filepath, hash|
        hash[filepath] = read_file_blob(filepath)
      end
    end

    memoize
    def important_filepaths
      [
        instructions_filepath,
        instructions_append_filepath,
        introduction_filepath,
        introduction_append_filepath,
        hints_filepath,
        *test_filepaths
      ].select do |filepath|
        filepaths.include?(filepath)
      end
    end

    memoize
    def important_absolute_filepaths
      important_filepaths.map { |filepath| absolute_filepath(filepath) }
    end

    memoize
    def cli_filepaths
      special_filepaths = SPECIAL_FILEPATHS.values_at(:config, :readme, :help)
      special_filepaths << SPECIAL_FILEPATHS[:hints] if filepaths.include?(hints_filepath)

      filtered_filepaths = filepaths.select do |filepath|
        next if filepath.start_with?('.docs/')
        next if filepath.start_with?('.meta/')
        next if example_filepaths.include?(filepath)
        next if exemplar_filepaths.include?(filepath)

        true
      end

      special_filepaths.concat(filtered_filepaths)
    end

    def read_file_blob(filepath)
      mapped = file_entries.map { |f| [f[:full], f[:oid]] }.to_h
      mapped[filepath] ? repo.read_blob(mapped[filepath]) : nil
    end

    def dir
      "exercises/#{exercise_type}/#{exercise_slug}"
    end

    private
    attr_reader :repo, :exercise_slug, :exercise_type, :git_sha

    def absolute_filepath(filepath)
      "#{dir}/#{filepath}"
    end

    def filepaths
      file_entries.map { |defn| defn[:full] }
    end

    memoize
    def file_entries
      tree.walk(:preorder).map do |root, entry|
        next if entry[:type] == :tree

        entry[:full] = "#{root}#{entry[:name]}"
        entry
      end.compact
    end

    memoize
    def tree
      repo.fetch_tree(commit, dir)
    end

    memoize
    def commit
      repo.lookup_commit(git_sha)
    end

    memoize
    def track
      Track.new(repo: repo)
    end
  end
end
