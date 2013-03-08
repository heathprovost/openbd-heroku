Open Bluedragon for Heroku
==========================

This is a Heroku [plugin](https://devcenter.heroku.com/articles/using-cli-plugins)/[buildpack](http://devcenter.heroku.com/articles/buildpack) for [Open Bluedragon](http://openbd.org/). It uses [Winstone](http://winstone.sourceforge.net/) to run your app.

Prerequisites
-----

* [Java JVM](http://www.java.com/en/download/index.jsp)
* [OpenBD Desktop](http://openbd.org/downloads/)
* [Heroku Toolbelt](https://toolbelt.heroku.com/)

Overview
-----

This project is targeted at developers who are already somewhat comfortable with Heroku and want to run OpenBD without a lot of complexity. There is no pom.xml, 
no war file deployment, no boilerplate configuration, and nothing to download. You
can go from nothing to running on heroku in less than 5 minutes - really.

Quick Start
-----

Assuming you already have all the prerequisites covered...

1. Install the plugin and read the basic help
		
		$ heroku plugins:install https://github.com/heathprovost/openbd-heroku.git
		$ heroku help openbd

2. Generate a new project and run it locally
		
		$ heroku openbd:generate your-app-name
		$ cd your-app-name
		$ foreman start

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

The buildpack will download and provision OpenBD engines as needed. It will keep a copy of the last engine version cached at all times, allowing subsequent deployments to skip
download the engine. An average cached deployment only takes about 10 seconds or so.


License
-------

Licensed under the MIT License. See LICENSE file.
