# Introduction

Quicktask is a lightweight but feature-rich task management plugin designed to easily and effectively track a list of tasks, their added and completed dates, time spent, notes, and so forth. Inspired by the todolist Vim syntax scheme created by Eric Talevich, Quicktask marries sensible and legible text coloration with keyboard shortcuts to keep you typing tasks rather than metadata.

![Quicktask screenshot](http://quicktask.aaronbieber.com/images/quicktask_screen.png)

# Installation

Quicktask is designed to be deployed as a Pathogen (or Vundle, etc.) bundle. Typically you would simply add the Git repository as a sub-module of your Vim configuration, or clone it into your bundles folder.

If you do not use Git to manage your Vim configuration, you can simply clone the repository into your `bundles` folder:

```
$ cd ~/.vim
$ git clone https://github.com/aaronbieber/quicktask.git bundles/quicktask
```

If you *do* use Git to manage your Vim configuration and you want to add Quicktask as a submodule, you would instead run these commands:

```
$ cd ~/.vim
$ git submodule add https://github.com/aaronbieber/quicktask.git bundles/quicktask
$ git submodule init
$ git submodule update
```

If you are using Windows, it's recommended that you use Cygwin. In Cygwin the process is basically the same except that you would `cd` into your Vim runtime directory rather than `~/.vim`.

# Help!

If you are using Pathogen, just run `:Helptags` after installing the plugin (with a capital "H"). If you are not using Pathogen, you need to run the regular `helptags` command on the `doc` folder of the plugin. Normally it would be something like:

```
:helptags ~/.vim/bundle/quicktask/doc
```

Once help tags have been generated, you can simply run `:h quicktask` to open the full manual.

# License

Quicktask is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

Quicktask is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with Quicktask.  If not, see <http://www.gnu.org/licenses/>.
