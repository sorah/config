# frozen_string_literal: true

require "pathname"

# Reads developer-local files under the app root. In a linked git worktree, a missing file
# falls back to the main checkout's copy; writes always go to the current checkout.
module LocalConfigFile
  APP_ROOT = File.expand_path("..", __dir__)

  class << self
    def candidates(relative_path, root: APP_ROOT)
      current_path = File.join(root.to_s, relative_path)
      [current_path, main_checkout_equivalent(current_path)].compact
    end

    def find(relative_path, root: APP_ROOT)
      candidates(relative_path, root:).find { |path| File.exist?(path) }
    end

    def read(relative_path, root: APP_ROOT)
      path = find(relative_path, root:)
      path && File.read(path).strip
    end

    def write_path(relative_path, root: APP_ROOT)
      File.join(root.to_s, relative_path)
    end

    def resolve_path(path, root: APP_ROOT)
      return path if Pathname.new(path).absolute?

      find(path, root:) || write_path(path, root:)
    end

    def reset_cache!
      @worktree_mappings = {}
    end

    def main_checkout_equivalent(path)
      path = File.expand_path(path)
      start = File.dirname(path)
      until File.exist?(start)
        parent = File.dirname(start)
        break if parent == start

        start = parent
      end
      mapping = worktree_mapping(start)
      return unless mapping

      worktree_root, main_root = mapping
      relative_path = Pathname.new(path).relative_path_from(Pathname.new(worktree_root)).to_s
      equivalent = File.join(main_root, relative_path)
      equivalent == path ? nil : equivalent
    end

    private def worktree_mapping(start)
      @worktree_mappings ||= {}
      return @worktree_mappings[start] if @worktree_mappings.key?(start)

      start_device = File.stat(start).dev
      ancestor = start
      mapping = nil

      loop do
        break unless File.stat(ancestor).dev == start_device

        dotgit = File.join(ancestor, ".git")
        break if File.directory?(dotgit)

        if File.file?(dotgit)
          main_root = main_checkout_root(dotgit)
          if main_root
            mapping = [ancestor, main_root]
            break
          end
        end

        parent = File.dirname(ancestor)
        break if parent == ancestor

        ancestor = parent
      end

      @worktree_mappings[start] = mapping
    rescue Errno::ENOENT, Errno::ENOTDIR
      @worktree_mappings[start] = nil
    end

    private def main_checkout_root(dotgit_file)
      contents = File.read(dotgit_file)
      return unless contents.start_with?("gitdir:")

      gitdir = resolve_pointer(contents.delete_prefix("gitdir:"), File.dirname(dotgit_file))
      return unless gitdir

      commondir = resolve_pointer(File.read(File.join(gitdir, "commondir")), gitdir)
      return unless commondir && File.basename(commondir) == ".git"
      return unless File.dirname(gitdir) == File.join(commondir, "worktrees")

      back_pointer = resolve_pointer(File.read(File.join(gitdir, "gitdir")), gitdir)
      return unless back_pointer == File.realpath(dotgit_file)

      File.dirname(commondir)
    end

    private def resolve_pointer(pointer, base)
      pointer = pointer.strip
      return if pointer.empty?

      path = Pathname.new(pointer)
      path = Pathname.new(base).join(path) if path.relative?
      File.realpath(path.to_s)
    end
  end
end
