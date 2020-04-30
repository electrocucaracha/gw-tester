# GW Tester Demo
[![Build Status](https://travis-ci.org/electrocucaracha/gw-tester.png)](https://travis-ci.org/electrocucaracha/gw-tester)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

## Summary

This project provides instructions required to setup the demo
described by *Yoshiyuki Kurauchi* in [this post][1]. The main goal of
this project is to provide an end-to-end implementation of a
Cloud-Native Network Function for didactic purposes.

![Architecture](docs/img/diagram.png)

### Concepts

* **User Equipment (UE):** This is the device that requests
connectivity to the network and downloads/uploads any data.
* **Evolved UMTS Terrestrial Radio Access Network (E-UTRAN):** The
network of antennas or Evolved Node B (EnodeB), gives radio access to
the UE anywhere there is coverage.
* **Public Data Network (PDN):** It is a shared network that is
accessed by users that belong to different organizations.
* **Evolved Packet Core (EPC):** It validates the session request from
the UE, generates a PDP context and gives access to the PDN.
  - *Mobility Management Entity (MME):* It does all the signaling for
the mobile devices but does not process any user data traffic. An MME
will provide session and mobility management for users. In addition,
it tracks the location of the UE and selects the S-GW and P-GW that
should serve this UE.
  - *Serving Gateway (S-GW):* In order to eliminate any effect on user
data while the UE moves between different eNodeBs, the S-GW works as
an anchor point for the user data of the UE, while the UE is moving
between different eNodeBs.
  - *PDN Gateway (P-GW):* This is the node that connects between the
LTE network and the PDN.

## Setup

This project uses [Vagrant tool][2] for provisioning Virtual Machines
automatically. It's highly recommended to use the  `setup.sh` script
of the [bootstrap-vagrant project][3] for installing Vagrant
dependencies and plugins required for its project. The script
supports two Virtualization providers (Libvirt and VirtualBox).

    $ curl -fsSL http://bit.ly/initVagrant | PROVIDER=libvirt bash

Once Vagrant is installed, it's possible to deploy the demo with the
following instruction:

    $ DEPLOY=k8s vagrant up

### Post-provision

Once the Virtual Machine is provisioned by Vagrant, it's possible to
check the logs of the different containers.

    $ vagrant ssh
    $ cd /vagrant
    $ make k8s-logs

### SkyDive

The [Skydive real-time network analyzer][4] is deployed during the
provisioning process, this [link](http://10.10.17.4:8082) allows to
access its dashboard.

![Skydive sample](docs/img/skydive.png)

[1]: https://wmnsk.com/posts/20200116_gw-tester/
[2]: https://www.vagrantup.com/
[3]: https://github.com/electrocucaracha/bootstrap-vagrant
[4]: https://skydive.network/
