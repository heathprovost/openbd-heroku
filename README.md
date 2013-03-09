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

This project is targeted at developers who are already somewhat comfortable with Heroku and want to run OpenBD without a lot of complexity. There is no pom.xml, 
no war file deployment, no boilerplate configuration, and nothing to download. You
can go from nothing to running on heroku in less than 5 minutes - really.

Quick Start
-----

Assuming you already have all the requirements covered...

1. Install the plugin and read the basic help
		
		$ heroku plugins:install http://github.com/heathprovost/openbd-heroku.git
		$ heroku help openbd

2. Generate a new project and run it locally
		
		$ heroku openbd:generate your-app-name
		$ cd your-app-name
		$ foreman start

		goto http://localhost:8080/ to see your running site

3. Put it in git

		$ git init
		$ git add .
		$ git commit -m "1st commit"

4. Create, deploy, and view on Heroku

		$ heroku openbd:create your-app-name
		$ git push heroku master
		$ heroku open		 

Under The Hood
-----

The plugin manages as much as it can for you, requiring minimal input. It currently
supports three sub-commands:

### openbd:generate

This command does just what it says - it generates a new project. It will provision
the engine as needed - downloading it from openbd.org if neccessary. By default, it
operates in "thin deployment" mode, i.e. it dynamically links your project with an
extenerally stored version of the openbd engine. This keeps the heaviest parts of
OpenBD out of your local project folder, making for quick deployments and a lightweight
repo. You can also do full engine deployments if you prefer, the choice is yours.

### openbd:update

Ever wished you could update your apps copy of OpenBD with a single command? Then this is for you. You just specify the version number you want to run and the plugin
will instantly upgrade or downgrade your project to the specified version. All stable
releases from 1.1 all the way up to 3.0 are supported. You can even run the nightly
build if you want to. The only restriction is this only works if you use thin deployments (the default). If you choose to use full engine deployments youll have
to fiddle with upgrading things yourself.

Note: Make sure to commit your changes to git after running this command.

### openbd:create

This command creates your application on Heroku. It works and acts more or less like the standard "heroku create" command, but it takes care of a bunch of boilerplate for
you. It knows which buildpack to assign and takes care of doing that part for you. You
can also set a password for the admin console (or let the plugin generate a strong password for you). This password will be used when your app is deployed on Heroku, so
you do not have to expose your password in revision control.

Buildpack
-----

This plugin is designed to use its own custom buildpack for deploying OpenBD. When you perform a deployment
(i.e. git push heroku master), the buildpack will run on your dyno and download and provision OpenBD as needed. It keeps a cached copy of the last engine used to so that it can skip downloading to speed up future deployments. An average cached deployment only takes about 10 seconds or so.

Support FAQ
-------

**How do I make sure I am running the latest version of the plugin?**

		$ heroku plugins:update openbd-heroku

**On Windows, everytime I use CTRL-C to stop my local server it says "Terminate batch job (Y/N)?". Is there a way to stop this from happening?**

For the long answer see [this](http://stackoverflow.com/questions/1234571/how-can-i-suppress-the-terminate-batch-job-in-cmd-exe). Short answer is to just hit CTRL-C twice.

**If I try to do "foreman start" on a project I created with a different user account it fails. What gives?**

Foreman occasionally has issues on Windows reading environment variables and expanding them in your Procfile. To work around this, the plugin sets $HOME inside of the .env file in your project to whatever the value was for the user who ran it originally. Just edit .env and set HOME to your current accounts home directory and you should be good to go.

**I don't want all this fancy stuff. I want OpenBD to work exactly like I'm used to. Can I do that?**

No problem. When you issue your openbd:generate command, just add --full-engine as an option. This will give you a completely vanilla installation, jars in /WEB-INF/lib, all the extra stuff like the manual, etc. You will not be able to use openbd:update to switch versions - you'll have to manage all upgrades yourself. Also, when you do deployments the buildpack will use your files directly - it will not try to download and provision OpenBD for you.

**I have an existing OpenBD project using ReadyToRun or OpenBD Desktop. Can I deploy it as is?**

Generally yes. All you should have to do is put your context root into git and skip straight to openbd:create. The only catch is instead of Jetty the buildpack uses Winstone to run your project on Heroku (primarily to save slug space since Winstone is so much smaller). You may find that you have issues getting things to work. A quick way to fix it is to copy the [web.xml](https://github.com/heathprovost/openbd-heroku/blob/master/opt/patches/WEB-INF/web.xml) file from this repo. It is already modified to work well with Winstone.

**It doesn't work! What do I do?**

[Post an issue](https://github.com/heathprovost/openbd-heroku/issues). I'll do what I can to help.


License
-------

Licensed under the MIT License. See [LICENSE file](https://github.com/heathprovost/openbd-heroku/blob/master/LICENSE.txt).
