Open Bluedragon for Heroku
==========================

This is a Heroku [plugin](https://devcenter.heroku.com/articles/using-cli-plugins)/[buildpack](http://devcenter.heroku.com/articles/buildpack) for [Open Bluedragon](http://openbd.org/). It uses [Winstone](http://winstone.sourceforge.net/) to run your app.

Requirements
-----

* [Java JVM](http://www.java.com/en/download/index.jsp)
* [Heroku Toolbelt](https://toolbelt.heroku.com/)
* Windows, Linux, or OSX. If Heroku Toolbelt works so should this plugin

Overview
-----

This project is targeted at developers who are already somewhat comfortable with Heroku and want to run OpenBD without a lot of complexity. There is no pom.xml, no war file deployment, no boilerplate configuration, and nothing to download. You can go from nothing to running on heroku in less than 5 minutes.

Quick Start
-----

Assuming you already have all the requirements covered...

1. Install the plugin and read the basic help
		
		$ heroku plugins:install http://github.com/heathprovost/openbd-heroku.git
		$ heroku help openbd

2. Generate a new project and run it locally (browse to http://localhost:8080/ to see your site)
		
		$ heroku openbd:generate your-app-name
		$ cd your-app-name
		$ foreman start

3. Create, deploy, and view on Heroku

		$ heroku openbd:heroku your-app-name
		$ git push heroku master
		$ heroku open		 

Under The Hood
-----

The plugin manages as much as it can for you, requiring minimal input. It currently supports the following commands:

### openbd:generate

**aliases:** _openbd:gen_, _openbd:new_

This command does just what it says - it generates a new project. It will provision the engine as needed - downloading it from openbd.org if neccessary. By default, it operates in "thin deployment" mode, i.e. it dynamically links your project with an extenerally stored version of the openbd engine. This keeps the heaviest parts of OpenBD out of your local project folder, making for quick deployments and a lightweight repo. You can also do full engine deployments if you prefer, the choice is yours. 

It will also, by default, initialize git in the created project folder and perform an initial commit. If you
prefer to do that yourself, just add the --no-git option. 

Another alternative is to set an environment variable called OPENBD_HEROKU_NO_GIT to true in your .bashrc or .bash_profile (or whatever you use to setup your environment). It this environment variable is set generate will act as if the --no-git option is always being passed to it.

### openbd:update

Ever wished you could update OpenBD with a single command? Then this is for you. You just specify the version number you want to run and the plugin will instantly upgrade or downgrade your project to the specified version. All stable releases from 1.1 all the way up to 3.0 are supported. You can even run the nightly build if you want to. The only restriction is it only works if you use thin deployments (the default). If you choose to use full engine deployments you will have to fiddle with things yourself.

Note: Make sure to commit your changes to git after running this command.

### openbd:heroku

**aliases:** _openbd:create_

This command creates your application on Heroku. It works and acts more or less like the standard "heroku create" command, but it takes care of a bunch of boilerplate for you. It knows which buildpack to assign and takes care of doing that part for you. You can also set a password for the admin console (or let the plugin generate a strong password for you). This password will be used when your app is deployed on Heroku, so you do not have to expose your password in revision control.

### openbd:info

Displays information about the plugin and your current project (when run inside your project folder). This will display quite a bit of usefule information - the name of your heroku app, the date and time of your last commit, and the deployment model and version of OpenBD used. It will also list all of the versions of OpenBD that are available for use.

Buildpack
-----

This plugin is designed to use it's own custom buildpack for deploying OpenBD. When you perform a deployment
(i.e. git push heroku master), the buildpack will run on your dyno and download and provision OpenBD as needed. It keeps a cached copy of the last engine used to so that it can skip downloading to speed up future deployments. On average a cached deployment takes only about 10 seconds or so.

Support FAQ
-------

Your question might be answered [here](https://github.com/heathprovost/openbd-heroku/wiki/FAQ)


License
-------

Licensed under the MIT License. See [LICENSE file](https://github.com/heathprovost/openbd-heroku/blob/master/LICENSE.txt).
