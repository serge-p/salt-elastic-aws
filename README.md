# Build a Secure Cloud ElasticSearch Instance exercise


deploy_vm.sh

* script to deploy a new Instance in AWS EC2 cloud, 
* script does not take any args


dependencies: 
~~~

1. Java needs to be installed on the machine 

2. install ec2-cli tools and set environment variables as described in AWS doc:
http://docs.aws.amazon.com/AWSEC2/latest/CommandLineReference/set-up-ec2-cli-linux.html

3. create authentication key-pair to access AWS console through API and set 2 following environment variables: 

```sh
 export AWS_ACCESS_KEY=XXXXXXXXXXXXXXXXXXXX
 export AWS_SECRET_KEY=XXXXXXXXXXXXXXXXXXXX
```

4. run script as following `./deploy_vm.sh` 

~~~


main script logic: 
~~~
* check for java executable and env variables 
* install latest ec2cli tools from amazon 
* create new keypair with name 'test' and show private key to access new instance  
* generate init shell script for initial bootstrap 
* start a new t2.micro instance in EC2 
* then bootstrap salt into newly created VM 
* clone this repository and apply highstate in a masterless mode 
* salt script files are available in folder salt/

~~~


drop_vm.sh 
~~~
script to terminate given EC2 instance, 
script takes instance ID as an argument
deps: (same as for deploy_vm.sh)
~~~


