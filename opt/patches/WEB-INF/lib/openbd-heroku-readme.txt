The files usually contained in this folder are deployed by the buildpack
when pushed to heroku. You are free to add you own .jar files here or even
add modified versions of existing jars.

The following limitations apply when running using the default thin deployment
model:

1. There is no support for emulating registry access. Do not use tags, functions
   or features that require /WEB-INF/bin/cfregistry.dll in order to work.
2. There is no support for native custom tags that use the original C API. Java
   customtags, however, are fully supported.