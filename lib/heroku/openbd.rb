require "heroku/command/base"
require "open-uri"
require "fileutils"
require "zip/zip"

# manage openbd projects and deployments
#
class Heroku::Command::Openbd < Heroku::Command::BaseWithApp

  OK_OBD_VERSIONS = ["nightly", "1.1", "1.2", "1.3", "1.4", "2.0", "2.0.1", "2.0.2", "3.0"]
  DEF_OBD_VERSION = OK_OBD_VERSIONS[-1]
  HOME_PATH = File.expand_path("~") + "/.openbd-heroku"
  BUFFER_SIZE = 1_024*1_024*1
  CURR_DIR = Dir.pwd

  # openbd:generate [NAME]
  #
  # generate a new openbd project
  #
  # -v, --version VERSION         # openbd version. Default is last stable release
  # -r, --rebuild                 # flush cache and download new openbd engine
  # -o, --overwrite               # recreate project, deleting ALL existing files
  # -f, --full-engine             # use complete engine, disabling thin deployment
  # -n, --no-git                  # skip git inititialize and commit
  #     --verbose                 # show detailed output
  #
  #Examples
  #
  # $ heroku openbd:generate
  # -----> Using OpenBD 3.0... done
  # -----> Initializing git repo and performing 1st commit... done
  # -----> Project 'openbd-project-1' created successfully.
  # Type 'cd openbd-project-1' to change to your project folder.
  # Type 'foreman start' to run the server locally  
  #
  # $ heroku openbd:generate foo --version 1.1 --verbose
  # -----> Using OpenBD 1.1... done
  # -----> Copying /bluedragon... done
  # -----> Copying /WEB-INF/webresources... done
  # -----> Initializing /WEB-INF/classes... done
  # -----> Initializing /WEB-INF/customtags... done
  # -----> Patching /index.cfm... done
  # -----> Patching /WEB-INF/bluedragon/log4j.properties... done
  # -----> Patching /WEB-INF/web.xml... done
  # -----> Patching /WEB-INF/bluedragon/bluedragon.xml... done
  # -----> Patching /WEB-INF/bluedragon/component.cfc... done
  # Initialized empty Git repository in /openbd/foo/.git/
  # [master (root-commit) 58d6e30] 1st commit
  # 7 files changed, 255 insertions(+), 0 deletions(-)
  # create mode 100644 .gitignore
  # create mode 100644 WEB-INF/bluedragon/bluedragon.xml
  # create mode 100644 WEB-INF/bluedragon/component.cfc
  # create mode 100644 WEB-INF/bluedragon/log4j.properties
  # create mode 100644 WEB-INF/lib/openbd-heroku-readme-1.1.txt
  # create mode 100644 WEB-INF/web.xml
  # create mode 100644 index.cfm
  # -----> Project 'foo' created successfully.
  # Type 'cd foo' to change to your project folder.
  # Type 'foreman start' to run the server locally
  #
  def generate
    $VERBOSE = !options[:verbose].nil?
    name = shift_argument || generate_app_name
    project_dir = "#{CURR_DIR}/#{name}"
    overwrite = !options[:overwrite].nil?
    if File.directory? project_dir
      if overwrite
        FileUtils.rm_r project_dir
      else
        if confirm "Project #{name} already exists. Should I replace it?"
          if confirm "This will delete ALL existing files. Are you ABSOLUTELY sure?"
            FileUtils.rm_r project_dir
          else 
            return
          end
        else
          return
        end
      end
    end
    version = options[:version]
    version = DEF_OBD_VERSION if version == nil
    unless OK_OBD_VERSIONS.include?(version)
      throw "Specified version \"#{version}\" isn't supported.\nTry one of the following:\n   #{OK_OBD_VERSIONS.join("\n   ")}"
    end
    rebuild = !options[:rebuild].nil?
    full_engine = !options[:full_engine].nil?
    no_git = !options[:no_git].nil?
    download_openbd(version, rebuild)
    update_project(name, version, full_engine, false, false)
    put_into_git(name) unless no_git
    display "-----> Project '#{name}' created successfully.\nType 'cd #{name}' to change to your project folder.\nType 'foreman start' to run the server locally"
  end

  # openbd:generate_no_git [NAME]
  #
  # alias for "openbd:generate --no-git"
  #
  # generate a new openbd project and put it into revision control
  #
  # -v, --version VERSION         # openbd version. Default is last stable release
  # -r, --rebuild                 # flush cache and download new openbd engine
  # -o, --overwrite               # recreate project, deleting ALL existing files
  # -f, --full-engine             # use complete engine, disabling thin deployment
  #     --verbose                 # show detailed output
  #
  #Examples
  #
  # $ heroku openbd:generate_no_git
  # -----> Using OpenBD 3.0... done
  # -----> Project 'openbd-project-1' created successfully.
  # Type 'cd openbd-project-1' to change to your project folder.
  # Type 'foreman start' to run the server locally  
  #
  # $ heroku openbd:generate_no_git foo --version 1.1 --verbose
  # -----> Using OpenBD 1.1... done
  # -----> Copying /bluedragon... done
  # -----> Copying /WEB-INF/webresources... done
  # -----> Initializing /WEB-INF/classes... done
  # -----> Initializing /WEB-INF/customtags... done
  # -----> Patching /index.cfm... done
  # -----> Patching /WEB-INF/bluedragon/log4j.properties... done
  # -----> Patching /WEB-INF/web.xml... done
  # -----> Patching /WEB-INF/bluedragon/bluedragon.xml... done
  # -----> Patching /WEB-INF/bluedragon/component.cfc... done
  # -----> Project 'foo' created successfully.
  # Type 'cd foo' to change to your project folder.
  # Type 'foreman start' to run the server locally
  #
  def generate_no_git
    args = ARGV.dup
    args.shift
    args << "--no-git"
    run_command("openbd:generate", args)
  end

  # openbd:create [NAME]
  #
  # create a new openbd app on heroku
  #
  #     --addons ADDONS        # a comma-delimited list of addons to install
  # -n, --no-remote            # don't create a git remote
  # -r, --remote REMOTE        # the git remote to create, default "heroku"
  # -p, --password PASSWORD    # admin console password, default auto generated
  #
  #Example
  #
  # $ heroku openbd:create my-openbd-app
  # Creating my-openbd-app... done, stack is cedar
  # http://my-openbd-app.herokuapp.com/ | git@heroku.com:my-openbd-app.git
  # Git remote heroku added
  #
  #NOTE: This is a replacement for 'heroku create'. Internally it does this: 
  #
  # $ heroku create [NAME] 
  #  --stack cedar 
  #  --buildpack http://github.com/heathprovost/openbd-heroku.git
  #
  # $ heroku config:set OPENBD_PASSWORD=[PASSWORD] --app [NAME]
  #
  # $ heroku labs:enable user-env-compile --app [NAME]
  #
  def create
    name = shift_argument || options[:app] || ENV['HEROKU_APP']
    validate_arguments!
    no_remote = !options[:no_remote].nil?
    remote = options[:remote]
    remote = "heroku" if remote == nil
    addons = options[:addons]
    password = options[:password]
    password = newpass if password == nil
    info = api.post_app({
      "name" => name,
      "stack" => "cedar"
    }).body
    begin
      action("Creating #{info['name']}") do
        if info['create_status'] == 'creating'
          Timeout::timeout(options[:timeout].to_i) do
            loop do
              break if api.get_app(info['name']).body['create_status'] == 'complete'
              sleep 1
            end
          end
        end
        if info['region']
          status("region is #{info['region']}")
        else
          status("stack is #{info['stack']}")
        end
      end
      
      (addons || "").split(",").each do |addon|
        addon.strip!
        action("Adding #{addon} to #{info["name"]}") do
          api.post_addon(info["name"], addon)
        end
      end

      api.put_config_vars(info["name"], "BUILDPACK_URL" => "http://github.com/heathprovost/openbd-heroku.git")
      api.put_config_vars(info["name"], "OPENBD_PASSWORD" => password)
      hputs([ info["web_url"], info["git_url"] ].join(" | "))
    
    rescue Timeout::Error
    
      hputs("Timed Out! Run `heroku status` to check for known platform issues.")
    
    end

    unless no_remote
      create_git_remote(remote, info["git_url"])
    end

    feature = api.get_features.body.detect { |f| f["name"] == "user-env-compile" }
    throw "Heroku labs feature \"user-env-compile\" is not available" unless feature
    api.post_feature("user-env-compile", name)

  end

  # openbd:update
  #
  # updates current project
  #
  # -v, --version VERSION         # openbd version. Default to use current version
  # -r, --rebuild                 # flush cache and download new copy of openbd
  # -o, --overwrite-config        # reset configuration files to defaults
  #     --verbose                 # show detailed output
  #  
  #Examples
  #
  # $ heroku openbd:update -v 1.2
  # -----> Using OpenBD 1.2... done
  # foo updated to OpenBD 1.2
  #
  # $ heroku openbd:update -v 1.2 --verbose
  # -----> Using OpenBD 1.2... done
  # -----> Copying /bluedragon... done
  # -----> Copying /WEB-INF/webresources... done
  # -----> Using existing /WEB-INF/classes... done
  # -----> Using existing /WEB-INF/customtags... done
  # -----> Using existing /index.cfm... done
  # -----> Using existing /WEB-INF/bluedragon/log4j.properties... done
  # -----> Using existing /WEB-INF/web.xml... done
  # -----> Using existing /WEB-INF/bluedragon/bluedragon.xml... done
  # -----> Using existing /WEB-INF/bluedragon/component.cfc... done
  # foo updated to OpenBD 1.2
  #
  def update
    is_valid_project
    $VERBOSE = !options[:verbose].nil?
    name = File.basename(CURR_DIR)
    project_dir = CURR_DIR
    overwrite_config = !options[:overwrite_config].nil?
    version = options[:version]
    unless version == nil or OK_OBD_VERSIONS.include?(version)
      throw "Specified version \"#{version}\" isn't supported.\nTry one of the following:\n   #{OK_OBD_VERSIONS.join("\n   ")}"
    end
    rebuild = !options[:rebuild].nil?
    download_openbd(version, rebuild) unless version.nil?
    update_project(name, version, false, overwrite_config, true)    
    display "#{name} updated to OpenBD #{version}" unless version.nil?
  end

  private

  def put_into_git(name)
    if !has_git?
      throw "Can't initialize repo. Git does not appear to be installed."
    elsif File.directory?("#{CURR_DIR}/#{name}/.git")
      "-----> INFO: existing git repo found [--git-init ignored]..."
    else
      Dir.chdir(name)
      if $VERBOSE
        system "git init"
        system "git add ."
        system "git commit -m \"1st commit\""
      else
        redisplay "-----> Initializing git repo and performing 1st commit..."
        `git init`
        `git add .`
        `git commit -m \"1st commit\"`
        redisplay "-----> Initializing git repo and performing 1st commit... done\n"
      end
      Dir.chdir(CURR_DIR)
    end
  end

  def update_project(name, version, full_engine, overwrite_config, is_update)
    if is_update
      project_dir = CURR_DIR
    else
      project_dir = "#{CURR_DIR}/#{name}"
    end
    FileUtils.mkdir_p project_dir
    if version.nil?
      display "-----> Using currently installed version of OpenBD..."
    elsif full_engine
      files = Dir.glob("#{HOME_PATH}/cache/#{version}/*")
      files.delete_if {|x| x =~ /^#{HOME_PATH}\/cache\/#{version}\/WEB-INF\/classes.*$/ or x =~ /^#{HOME_PATH}\/cache\/#{version}\/WEB-INF\/customtags.*$/ }
      redisplay "-----> Copying full engine for deployment... done\n"
      FileUtils.cp_r files, "#{project_dir}"
      files = Dir.glob("#{project_dir}/WEB-INF/classes/*")
      FileUtils.rm_r files
      files = Dir.glob("#{project_dir}/WEB-INF/customtags/*")
      FileUtils.rm_r files
      write_file "#{project_dir}/.gitignore", "/Procfile\n/.env\n/WEB-INF/bluedragon/work/\n/WEB-INF/bluedragon/bluedragon.xml.bak.*\n"
      write_file "#{project_dir}/.env", "HOME=#{home_directory}\nPORT=8080\nJAVA_OPTS=-Xmx128m -Xss512k" 
      write_file "#{project_dir}/Procfile", "web: java $JAVA_OPTS -Dlog4j.configuration=file:WEB-INF/bluedragon/log4j.properties -jar $HOME/.heroku/plugins/openbd-heroku/opt/server-engines/winstone-lite-0.9.10.jar --webroot=. --httpPort=$PORT"
    else
      #Copy required directories
      folders = ["/bluedragon", "/WEB-INF/webresources"]
      folders.each { |folder|
        do_copy = true
        if File.directory?("#{project_dir}#{folder}")
          do_copy = false
          if is_update
            FileUtils.rm_r "#{project_dir}#{folder}"
            v_redisplay "-----> Copying #{folder}..."
            do_copy = true
          elsif confirm "-----> Directory #{folder} already exists. Should I replace it?"
            FileUtils.rm_r "#{project_dir}#{folder}"
            v_redisplay "-----> Copying #{folder}..."
            do_copy = true
          else
            v_redisplay "-----> Using existing #{folder}... done\n"
          end
        else
          v_redisplay "-----> Copying #{folder}..."
        end
        if do_copy
          files = Dir.glob("#{HOME_PATH}/cache/#{version}#{folder}/*")
          FileUtils.mkdir_p "#{project_dir}#{folder}"
          v_redisplay "-----> Copying #{folder}... done\n"
          FileUtils.cp_r files, "#{project_dir}#{folder}"
        end
      }
      #initialize any remaining required directories
      folders = ["/WEB-INF/classes", "/WEB-INF/customtags"]
      folders.each { |folder|
        do_copy = true
        if File.directory?("#{project_dir}#{folder}")
          do_copy = false
          v_redisplay "-----> Using existing #{folder}... done\n"
        else
          v_redisplay "-----> Initializing #{folder}..."
        end
        if do_copy
          FileUtils.mkdir_p "#{project_dir}#{folder}"
          v_redisplay "-----> Initializing #{folder}... done\n"
        end
      }
      #write readme file
      file = Dir.glob("#{project_dir}/WEB-INF/lib/openbd-heroku-readme-*.txt")
      FileUtils.rm file unless file.empty?
      FileUtils.mkdir_p File.dirname("#{project_dir}/WEB-INF/lib/openbd-heroku-readme-#{version}.txt")
      FileUtils.cp "#{PLUGIN_PATH}/opt/patches/WEB-INF/lib/openbd-heroku-readme.txt", "#{project_dir}/WEB-INF/lib/openbd-heroku-readme-#{version}.txt"
      write_file "#{project_dir}/.gitignore", "/Procfile\n/.env\n/bluedragon/\n/WEB-INF/bluedragon/work/\n/WEB-INF/webresources/\n/WEB-INF/bluedragon/bluedragon.xml.bak.*\n"
      write_file "#{project_dir}/.env", "HOME=#{home_directory}\nPORT=8080\nJAVA_OPTS=-Xmx128m -Xss512k" 
      write_file "#{project_dir}/Procfile", "web: java $JAVA_OPTS -Dlog4j.configuration=file:WEB-INF/bluedragon/log4j.properties -jar $HOME/.heroku/plugins/openbd-heroku/opt/server-engines/winstone-lite-0.9.10.jar --commonLibFolder=$HOME/.openbd-heroku/cache/#{version}/WEB-INF/lib --webroot=. --httpPort=$PORT"
    end
    #Copy patched files
    if full_engine
      patchfiles = ["/WEB-INF/bluedragon/log4j.properties", "/WEB-INF/web.xml", "/WEB-INF/bluedragon/bluedragon.xml", "/WEB-INF/bluedragon/component.cfc"]
    else
      patchfiles = ["/index.cfm", "/WEB-INF/bluedragon/log4j.properties", "/WEB-INF/web.xml", "/WEB-INF/bluedragon/bluedragon.xml", "/WEB-INF/bluedragon/component.cfc"]
    end
    patchfiles.each { |file|
      do_copy = true
      if File.file?("#{project_dir}#{file}")
        do_copy = false
        if file == "/WEB-INF/web.xml" or file == "/WEB-INF/bluedragon/bluedragon.xml"
          if overwrite_config or full_engine
            FileUtils.rm "#{project_dir}#{file}"
            redisplay "-----> Patching #{file}..."
            do_copy = true
          else
            v_redisplay "-----> Using existing #{file}... done\n"
          end
        elsif file == "/index.cfm" or file == "/WEB-INF/bluedragon/log4j.properties" or file == "/WEB-INF/bluedragon/component.cfc"
          v_redisplay "-----> Using existing #{file}... done\n"
        else          
          if confirm "-----> File #{file} already exists. Should I replace it?"
            FileUtils.rm_r "#{project_dir}#{file}"
            v_redisplay "-----> Patching #{file}..."
            do_copy = true
          else
            v_redisplay "-----> Using existing #{file}... done\n"
          end
        end
      else
        v_redisplay "-----> Patching #{file}..."
      end
      if do_copy
        FileUtils.mkdir_p File.dirname("#{project_dir}#{file}")
        FileUtils.cp "#{PLUGIN_PATH}/opt/patches#{file}", "#{project_dir}#{file}"
        if overwrite_config or full_engine
          redisplay "-----> Patching #{file}... done\n"
        else
          v_redisplay "-----> Patching #{file}... done\n"
        end
      end
    }
  end

  def download_openbd(version, rebuild)
    url = "http://openbd.org/download/#{version}/openbd.war"
    filepath = "#{HOME_PATH}/cache/#{version}"
    filename = "openbd.war"
    savefile = "#{filepath}/#{filename}"
    openbd_jar = "#{filepath}/WEB-INF/lib/OpenBlueDragon.jar"
    content_len = 0
    FileUtils.rm_r filepath if rebuild and File.directory?(filepath)
    if File.exists?(openbd_jar)
      if version == "nightly"
        created = File.ctime(openbd_jar).strftime("%Y-%m-%d")
        display "-----> Using OpenBD #{version} [#{created}]... done"
      else
        display "-----> Using OpenBD #{version}... done"
      end
    else
      FileUtils.mkdir_p(filepath)
      open(url, "r", 
        :content_length_proc => lambda { |content_length| 
          content_len = content_length 
        },
        :progress_proc => lambda { |size|
          redisplay "-----> Using OpenBD #{version}... downloading #{size}/#{content_len} bytes" 
        }
      ) do |input|
        open("#{savefile}", "wb") do |output|
          while (buffer = input.read(BUFFER_SIZE))
            output.write(buffer)
          end
        end
      end
      redisplay "-----> Using OpenBD #{version}... extracting" 
      unzip(savefile, filepath)
      File.delete(savefile)
      redisplay "-----> Using OpenBD #{version}... done\n" 
    end
  end

  def throw(msg)
    raise Heroku::Command::CommandFailed, msg 
  end

  def write_file(file, txt)
    File.open(file, "w") {|f| f.write(txt) }
  end

  def is_valid_project
    check_files = ["/Procfile", "/WEB-INF/web.xml", "/WEB-INF/bluedragon/bluedragon.xml"]
    check_files.each { |file|
      unless File.exists?("#{CURR_DIR}#{file}")
        throw "Current directory is not an openbd project"
      end  
    }
    if Dir.glob("#{CURR_DIR}/WEB-INF/lib/openbd-heroku-readme-*.txt").empty?
      throw "Current project is not setup for thin deployment\nModifications to OpenBD must be performed manually"
    end
  end

  def is_in_git
    unless File.directory?("#{CURR_DIR}/.git")
      throw "Current directory is not checked into git yet. Run:\n   'git init'\n   'git add .'\n   'git commit -m \"1st commit\"'"
    end  
  end

  def v_display(msg)
    display msg if $VERBOSE
  end

  def v_redisplay(msg)
    redisplay msg if $VERBOSE
  end

  def newpass(len = 16)
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    newpass = ""
    1.upto(len) { |i| newpass << chars[rand(chars.size-1)] }
    return newpass
  end

  def generate_app_name
    prefix = "openbd-project"
    suffix = 0
    name = prefix
    while File.directory?("#{CURR_DIR}/#{name}")
      suffix = suffix + 1
      name = "#{prefix}-#{suffix}"
    end
    return name
  end

  def unzip(file, destination)
    Zip::ZipFile.open(file) { |zip_file|
      zip_file.each { |f|
        f_path = File.join(destination, f.name)
        FileUtils.mkdir_p(File.dirname(f_path))
        zip_file.extract(f, f_path) unless File.exist?(f_path)
      }
    }
  end

end