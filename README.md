# Implementing qubernetes a.k.a. Quorum blockchain on Kubernetes
This is for building a test quorum blcokchain 7node on AWS EKS.
https://github.com/jpmorganchase/qubernetes.git

## Inputs
* __cidr\_block__ - CIDR block value to use when creating the VPC.
* __name\_prefix__ - Prefix name to use when nameing things.
* __az\_count__ - Number of availability zones to deploy the cluster to.
* __region__ - The region to deploy the cluster to.
* __aws\_profile__ - The local AWS profile to use (Test enviornment only).

All `inputs` have sane defaults so no configuration required to test.

## To deploy
```
terraform init
terraform plan
terraform apply
```
## To test out everything
```
cd downloads/qubernetes
./connect.sh node1 quorum
```

Once inside the node
```
cd $QHOME/contracts
./runscript.sh public_contract.sh
```

Take note of the TransactionHash
```
Contract transaction send: TransactionHash: 0xd1bf0c15546802e5a121f79d0d8e6f0fa45d4961ef8ab9598885d28084cfa909 waiting to be mined...
true
````

To run commands from the `geth` console:
```
etc.blockNumber
```
```
eth.getTransaction('0xd1bf0c15546802e5a121f79d0d8e6f0fa45d4961ef8ab9598885d28084cfa909')
```
```
exit
```

## Other References
* Uses terraform modules from the `terraform-aws-modules` project for building out the VPC and the EKS cluster.
  * https://github.com/terraform-aws-modules/terraform-aws-vpc.git
  * https://github.com/terraform-aws-modules/terraform-aws-eks.git
