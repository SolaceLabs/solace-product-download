[![Build Status](https://travis-ci.org/SolaceLabs/solace-product-download.svg?branch=master)](https://travis-ci.org/SolaceLabs/solace-product-download)

# Solace Product Download
A project that supports automation for downloading Solace Products from (https://products.solace.com). It does so by providing an implementation of a Concourse resource to perform this download.
## Contents
* [Overview](#overview)
* [Concourse Configurations](#concourse-configurations)
* [Standalone Script](#standalone-script)
* [Development](#development)
* [Contributing](#contributing)
* [Authors](#authors)
* [License](#license)
* [Additional Resources](#additional-resources)
---
## Overview
The solace-product-download implements a Concourse resource. The resource facilitates calling the [downloadLicensedSolaceProduct](bin/downloadLicensedSolaceProduct.sh) script used to download products from Solace. The script can download any product from the [Solace Products domain](https://products.solace.com/).

## Concourse Configurations
solace-product-download can be added to a Concourse pipeline yaml. There are a couple of possible supported configurations.
#### Direct download
```
resource_types:
- name: solace-product-download
  type: docker-image
  source:
    repository: solace/solace-product-download
    tag: latest
  [...]
resource:
- name: solace-tile
  type: solace-product-download
  source:
    username: {{solace-product-username}}
    password: {{solace-product-password}}
    filepath: "/products/2.2GA/PCF/Current/2.2.1/solace-pubsub-2.2.1-enterprise.pivotal"
    accept_terms: true
  [...]
jobs:
- name: demo-resource
  plan:
  - get: solace-tile
  - task: my-task
    config:
      inputs:
      - name: solace-tile
  [...]
```
This will create a resource called `solace-tile` of type `solace-product-download` which is given a filepath relative to https://products.solace.com/ as well as Solace product credentials. Furthermore, the accept_terms flag is required to accept the Solace Systems Software License Agreement found [here](https://products.solace.com/Solace-Systems-Software-License-Agreement.pdf). The Software License Agreement will also be part of the download in addition to the requested filepath.

#### Solace PubSub+ for PCF Download
```
- name: solace-product-download
  type: docker-image
  source:
    repository: solace/solace-product-download
    tag: latest
  [...]
resource:
- name: solace-tile
  type: solace-product-download
  source:
    username: {{solace-product-username}}
    password: {{solace-product-password}}
    pivnet_token: {{uaa_refresh_token_for_pivnet}} # Pivotal Network UAA token found in Settings
    accept_terms: true
  [...]
jobs:
- name: demo-resource
  plan:
  - get: solace-tile
  - task: my-task
    config:
      inputs:
      - name: solace-tile
  [...]
```
This configuration, instead of downloading a specific product file based on filepath, will download the latest Solace PubSub+ Enterprise for PCF. This configuration requires a `pivnet_token` as your PivNet credentials in addition to the [Solace products](https://products.solace.com/) credentials.
With this configuration the `solace-tile` resource will download a checksum file from Pivotal Network Solace Pubsub+ (https://network.pivotal.io/products/solace-pubsub).
The checksum file will be interpreted to download the corresponding product from [Solace products](https://products.solace.com/), the downloaded file will be verified using this checksum. Using the configuration implies user's acceptance of the Solace Systems Software License Agreement. You must also accept the EULA of Solace Pubsub+ on Pivnet found [here](https://network.pivotal.io/legal_document_agreements/686270) which is required to download from PivNet.

## Standalone Script
The [downloadLicensedSolaceProduct](bin/downloadLicensedSolaceProduct.sh) script can be used standalone to automate the download of products from solace. An invocation of the script is as follows
```
downloadLicensedSolaceProduct.sh -u "solace-username" -p "solace-password" -d "/path/of/file-to-download" -a [-c "/path/to/checksumfile"]
```
The username (-u) and password (-p) are credentials for https://product.solace.com/, the download path (-d) is the path relative to https://product.solace.com/ and -a is required to signify acceptance of the solace license agreement found [here](https://products.solace.com/Solace-Systems-Software-License-Agreement.pdf). Optionally, a checksum file can be provided (with -c) to verify the downloaded product.

## Development
The project can be built locally by calling
```
./build.sh -l
```
To iterate, this can be pushed to a local or private docker registry. See [Deploying a Registry Server](https://docs.docker.com/registry/deploying/) for more information on local docker registrys.
```
./build.sh -r <local docker registry> [-u <username> -p <password>]
```
If using an insecure docker registry, a Concourse pipeline can be configured as follows to find the development version of solace-product-download
```
resource_types:
- name: solace-tile
  type: docker-image
  source:
    repository: my.local.docker:port/solace-product-download
    tag: latest
    insecure_registries: ["my.local.docker:port"]
```
## Contributing
Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.
## Authors
See the list of [contributors](graphs/contributors) who participated in this project.
## License
This project is licensed under the Apache License, Version 2.0. - See [LICENSE](LICENSE) file for details
## Additional Resources
For more information about Concourse resources, check out
* https://concourse-ci.org/implementing-resources.html

For more information about Solace, visit
* Solace Homepage https://solace.com
* The Solace Developer Portal website at https://dev.solace.com
* Solace Pubsub+ for PCF https://network.pivotal.io/products/solace-pubsub
