module Babushka
  class GemHelper < PkgHelper
  class << self
    def pkg_type; :gem end
    def pkg_cmd; 'gem' end
    def manager_key; :gem end
    def manager_dep; 'rubygems' end

    def _install! pkgs, opts
      # determine if to add rvm command prefix 
      rvm_cmd   = with_rvm? ? "rvm #{@rvm_string} " : ""
      ruby_info = with_rvm? ? "in rvm #{@rvm_string}" : "system ruby"
      pkgs.each do |pkg|
        key = "Installing #{pkg} via #{manager_key} #{ruby_info}"
        command = "#{rvm_cmd}#{pkg_cmd} install #{cmdline_spec_for pkg} #{opts}"
        log_shell key, command, :sudo => should_sudo?
      end
    end

    def install gemname, version_string=nil
      log "Using #{current_ruby_version} #{with_rvm? ? "(using rvm)" : "(system ruby)"}"
      rvm_cmd   = with_rvm? ? "rvm #{@ruby_string} " : ""
      log "About to run command: #{rvm_cmd}gem install #{gemname} #{version_string}"
      log_shell "Installing #{gemname} #{version_string||"latest"}", "#{rvm_cmd}gem install #{gemname} #{version_string}" do |shell|
        shell.stdout.split("\n").last
      end
    end

    def with_ruby ruby_version, gemset="global"
      with_ruby_string "#{ruby_version}@#{gemset}"
    end

    # Will set the current ruby string to use with rvm
    def with_ruby_string ruby_string
      @ruby_string = ruby_string
      self
    end

    # Will reset the ruby string to use the default
    def reset_ruby
      @ruby_string = nil
      @_cached_env_info= nil
    end

    # Determine if we are intending to use rvm support
    def with_rvm?
      !@ruby_string.nil?
    end

    # Respond with the current ruby version (rvm or system)
    def current_ruby_version
      with_rvm? ? full_ruby_version(@ruby_string) : shell("ruby -v")
    end

    # Expand an rvm alias to a full string
    def full_ruby_version name
      shell("rvm tools strings #{name}")
    end

    def gem_path_for gem_name, version = nil
      unless (detected_version = has?(ver(gem_name, version), :log => false)).nil?
        gem_root / ver(gem_name, detected_version)
      end
    end

    def bin_path
      # The directory in which the binaries from gems are found. This is
      # sometimes different to where `gem` itself is running from.
      env_info.val_for('EXECUTABLE DIRECTORY').p
    end

    def gem_root
      gemdir / 'gems'
    end

    def gemspec_dir
      gemdir / 'specifications'
    end

    def gemdir
      env_info.val_for('INSTALLATION DIRECTORY')
    end

    def ruby_path
      env_info.val_for('RUBY EXECUTABLE').p
    end

    def ruby_wrapper_path
      if ruby_path.to_s['/.rvm/rubies/'].nil?
        ruby_path
      else
        ruby_path.sub(
          # /Users/ben/.rvm/rubies/ruby-1.9.2-p0/bin/ruby
          /^(.*)\/\.rvm\/rubies\/([^\/]+)\/bin\/ruby/
        ) {
          # /Users/ben/.rvm/wrappers/ruby-1.9.2-p0/ruby
          "#{$1}/.rvm/wrappers/#{$2}/ruby"
        }
      end
    end

    def ruby_arch
      if RUBY_PLATFORM =~ /universal/
        "universal"
      elsif RUBY_PLATFORM == "java"
        "java"
      elsif RUBY_PLATFORM =~ /darwin/
        # e.g. "/opt/ruby-enterprise/bin/ruby: Mach-O 64-bit executable x86_64"
        shell("file -L '#{ruby_path}'").sub(/.* /, '')
      else
        Base.host.cpu_type
      end
    end

    def ruby_binary_slug
      [
        (defined?(RUBY_ENGINE) ? RUBY_ENGINE : 'ruby'),
        RUBY_VERSION,
        ruby_arch,
        (RUBY_PLATFORM['darwin'] ? 'macosx' : RUBY_PLATFORM.sub(/^.*?-/, ''))
      ].join('-')
    end

    def slug_for ruby
      shell %Q{#{ruby} -e "require '#{Babushka::Path.lib / 'babushka'}'; puts Babushka::GemHelper.ruby_binary_slug"}
    end

    # Determine if to use sudo.
    # If using rvm always false else determine writable
    def should_sudo?
      if with_rvm?
        false
      else
        super || (gem_root.exists? && !gem_root.writable?)
      end
    end

    def version
      env_info.val_for('RUBYGEMS VERSION').to_version
    end

    def update!
      shell('gem update --system', :sudo => !which('gem').p.writable?).tap {|result|
        @_cached_env_info = nil # `gem` changed, so this info needs re-fetching
      }
    end

    def installed_versions package_name
      versions = versions_of(package_name)
      versions.empty? ? "none" : versions.collect { |v| v.to_s }.join(", ")
    end

    private

    def _has? pkg
      versions_of(pkg).sort.reverse.detect do |version|
        pkg.matches? version
      end
    end

    def versions_of pkg
      pkg_name = pkg.respond_to?(:name) ? pkg.name : pkg
      gemspecs_for(pkg_name).select {|i|
        i.p.read.val_for('s.name')[/^[\'\"\%qQ\{]*#{pkg_name}[\'\"\}]*$/]
      }.map {|i|
        File.basename(i).scan(/^#{pkg_name}-(.*).gemspec$/).flatten.first
      }.map {|i|
        i.to_version
      }.sort
    end

    def gemspecs_for pkg_name
      gemspec_dir.glob("#{pkg_name}-*.gemspec")
    end

    def env_info
      unless with_rvm?
        @_cached_env_info ||= shell("gem env")
      else
        # clear out if this request is for a new ruby
        @_cached_env_info = nil if(@ruby_string != @last_ruby_string)
        @ruby_string ||= "default"
        @last_ruby_string = @ruby_string
        @_cached_env_info ||= shell("rvm #{@ruby_string} gem env")
      end
    end
  end
  end
end
