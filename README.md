<a href="https://flutter.dev/">
  <h4 align="center">
    <picture>
      <img alt="Flutter" height="300px" src="https://raw.githubusercontent.com/ServOKio/CImaGen/main/icon.png">
    </picture>
  </h4>
</a>
<h1 align="center">CImaGen</h1>
<p align="center">"What the hell is the difference between them?!"</p>

## About CImaGen

Initially, I just needed some simple application to get exif data from an image to view the generation parameters, but then I wanted to do something more that would help me generate images

## Building

1. Android studio
2. Visual studio 2019 ~16.11 (why 16.11 ? Because the Clang compiler that is needed for the [rive](https://github.com/rive-app/rive-flutter/issues/369#issuecomment-2022541422) plugin is in this version) + "Desktop development with C++"
3. CMake version 3.14.0 (Note: if you are using Visual Studio 2019 and get the error "Could not create named generator Visual Studio 16 2019" then you need to replace CMake inside Visual Studio with version 3.14. Just install CMake 3.14 and replace all files in ~`C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin` to 3.14 files)
