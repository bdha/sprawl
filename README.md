sprawl
======

Simple Cloud Provisioning Software for SmartOS

WARNING
=======

This is a prototype. See Limitations.

Requirements
============

* SmartOS

Perl modules:

* Catalyst::Runtime
* Catalyst::Devel
* Catalyst::Controller::REST
* HTTP::Tiny
* JSON
* YAML::XS
* XML::Simple
* String::Random
* App::Cmd::Simple
* Text::Table

Limitations
===========
Currently only supports one endpoint. In the future, there will be a front-end API dispatcher which enqueues requests to backend compute nodes. For the moment, you can only manage one SmartOS system.

At the moment, there is no authentication mechanism. Make sure you only install this if you trust your network.

Issues
======

* Assumes template configs are in /zones/machines
* Does not populate template config with the contents of compute.yml
* SmartOS Perl is broken if you install 32bit gcc via pkgin. You'll need to build your own.

Installation
============

Install SmartOS on a system (henceforce referred to as "the compute node") and configure it with stable storage.

Install the required Perl modules.

On the compute node:

    # cd /opt
    # git clone git@github.com:bdha/sprawl.git

You will need to pull in the smartos64 dataset from Joyent if you want to use joyent-branded zones.

See: http://wiki.smartos.org/display/DOC/How+to+Use+the+SmartOS+ISO+Image#HowtoUsetheSmartOSISOImage-CreatingZones

Templates
========

Templates are not magical. You will need to build your own, and populate their init scripts. At some point we'll distribute something to pull in metadata from upstream to configure the template magically.

Until then, see: http://wiki.smartos.org/display/DOC/How+to+create+a+Virtual+Machine+in+SmartOS

Configuration
=============

Modify the sprawl/apps/compute/compute.yml file.

In another terminal, create a file called ~/.sprawl.yml and populate it with some YAML config:

    ---
    endpoint: localhost:3000
    user: somestring
    secret: someotherstring

Create a dataset mounted on /usbkey. Populate /usbkey/config with:

    private_nic=0:21:28:c0:75:93
    external_nic=0:21:28:c0:75:92

Replace the MACs with your interfaces.

Usage
=====

On the compute node, execute the Catalyst test server.

    # cd sprawl/apps/compute/script/compute_server.pl -r

Now you can go ahead and interface with the API:

    export PERL5LIB=~/sprawl/lib
    cd bin/
    ./sprawl 
    ./sprawl create -s medium -t smartos64 -h happybox -d example.com -s ops1
    ./sprawl list

Author
======

Bryan Horstmann-Allen <bda@mirrorshades.net>
