This is a packer.io file that will create and EC2 AMI of a Teamcity agent that is build for php and docker.

##How to use this packer.io file:

1. copy the `variables.json.example` to `variables.json`
2. fill out the variables in the new json file
3. run packer build --var-file=variables.json agent.json

This will give you an AMI number, feel free to use this in your teamcity agents cloud config.