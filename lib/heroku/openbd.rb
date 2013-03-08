require "heroku/command/base"
require "open-uri"
require "fileutils"
require "zlib"

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
  # -f, --full-engine             # use complete engine and disable thin deployment
  #     --verbose                 # show detailed output
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
    download_openbd(version, rebuild)
    update_project(name, version, full_engine, false, false)
    display "-----> Project '#{name}' created successfully.\nType 'cd #{name}' to change to your project folder.\nType 'foreman start' to run the server locally"
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
  #This command acts as an alias for 'heroku apps:create', supplying some 
  #hardcoded options, setting config variables and options. Internally it does the
  #following: 
  #
  # $ heroku create [NAME] 
  #  --stack cedar 
  #  --buildpack http://github.com/heathprovost/openbd-heroku.git
  #
  # $ heroku config:set
  #  OPENBD_PASSWORD=[PASSWORD]
  #  --app [NAME]
  #
  # $ heroku labs:enable user-env-compile
  #  --app [NAME]
  #
  def create
    name = shift_argument || options[:app] || ENV['HEROKU_APP']
    no_remote = !options[:no_remote].nil?
    remote = options[:remote]
    remote = "heroku" if remote == nil
    addons = options[:addons]
    password = options[:password]
    password = newpass if password == nil
    opts = ""
    if no_remote
      opts = opts + "--no-remote "
    else
      opts = opts + "--remote #{remote}"
    end
    opts = opts + "--addons #{addons}" unless addons.nil?
    system "heroku apps:create #{name} #{opts} --stack cedar --buildpack http://github.com/heathprovost/openbd-heroku.git"
    system "heroku config:set OPENBD_PASSWORD=#{password} --app #{name}"
    system "heroku labs:enable user-env-compile --app #{name}"
  end

  # openbd:update
  #
  # updates version of openbd in current project
  #
  # -v, --version VERSION         # openbd version. Default to use current version
  # -r, --rebuild                 # flush cache and download new openbd engine
  # -o, --overwrite-config        # overwrite configuration files and use default settings
  #     --verbose                 # show detailed output
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
      write_file "#{project_dir}/.env", "PORT=8080\nJAVA_OPTS=-Xmx384m -Xss512k -XX:+UseCompressedOops" 
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
      write_file "#{project_dir}/.env", "PORT=8080\nJAVA_OPTS=-Xmx384m -Xss512k -XX:+UseCompressedOops" 
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
      Dir.chdir(filepath)
      system "jar xf openbd.war"
      File.delete(savefile)
      Dir.chdir(CURR_DIR)
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

end