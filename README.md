Solr Scale Toolkit
========

Fabric-based framework for deploying and managing SolrCloud clusters in the cloud.

Questions?
========

Please visit the Google Groups forum - https://groups.google.com/forum/#!forum/solr-scale-toolkit


Setup
========

Make sure you're running Python 2.7 and have installed Fabric and boto dependencies. 

On the Mac, you can do:

```
sudo easy_install fabric
sudo easy_install boto
```

For more information about fabric, see: http://docs.fabfile.org/en/1.8/

Clone the pysolr project from github and set it up as well:
```
git clone https://github.com/toastdriven/pysolr.git
cd pysolr
sudo python setup.py install
```
Note, you do not need to know any Python in order to use this framework.

Local Setup
========

The framework supports running a local single-node cluster on your workstation or a remote cluster running in the Amazon cloud (EC2). In fact, you can have multiple local clusters, such as if you need to test different versions of SolrCloud or Fusion.

To setup a local cluster, do:

1) Enable passphraseless SSH to localhost, i.e. ssh username@localhost should log in immediately without prompting you for a password. Typically, this is accomplished by doing:
```
$ ssh-keygen -t dsa -P '' -f ~/.ssh/id_dsa
$ cat ~/.ssh/id_dsa.pub >> ~/.ssh/authorized_keys
```
2) Run the *setup_local* task to configure a local cluster 

For instance:

```
fab setup_local:local,~/dev/lucidworks,fusionVers=2.4.2
```

This task will download Solr (5.5.2), ZooKeeper (3.4.6), and Fusion (2.4.2) and install them to a local path provided as a task parameter (~/dev/lucidworks). Specifically, you'll end up having:

```
~/dev/lucidworks/solr-5.5.2
~/dev/lucidworks/zookeeper-3.4.6
~/dev/lucidworks/fusion
```

Of course, if you already have Solr/ZooKeeper/Fusion downloaded, you can manually copy them into ~/dev/lucidworks/ to save re-downloading them; just be sure to name the directories based on the versions expected by the script.

After installing, the *setup_local* task will save the settings in your ~/.sstk file and start SolrCloud and Fusion services on your local workstation.

NOTE: even though Fusion includes an embedded version of Solr, using the Solr-Scale-Toolkit requires an external SolrCloud and ZooKeeper setup, which is why the setup_local task downloads ZooKeeper and Solr separately.

The "local" cluster definition is saved to ~/.sstk file as JSON:
```
{
  "clusters": {
    "local": {
      "name": "local",
      "hosts": [ "localhost" ],
      "provider:": "local",
      "ssh_user": "YOU",
      "ssh_keyfile_path_on_local": "",
      "username": "${ssh_user}",
      "user_home": "~/dev/lucidworks",
      "solr_java_home": "/Library/Java/JavaVirtualMachines/jdk1.7.0_67.jdk/Contents/Home",
      "zk_home": "${user_home}/zookeeper-3.4.6",
      "zk_data_dir": "${zk_home}/data",
      "instance_type": "m3.large",
      "sstk_cloud_dir": "${user_home}/cloud",
      "solr_tip": "${user_home}/solr-5.5.2",
      "fusion_home": "${user_home}/fusion"
    }
  }
}
```
Behind the scenes, the "local" cluster object overrides property settings that allow the Fabric tasks to work with your local directory structure / environment. For instance, the location of the Solr directory to use to launch the cluster will be resolved to: ~/dev/lucidworks/solr-4.10.2 because the ${user_home} variable is resolved dynamically to ~/dev/lucidworks.

Once the local cluster is defined, you can run any of the Fabric tasks that take a cluster ID using: fab <task>:local, such as fab setup_solrcloud:local,... will setup a SolrCloud cluster using the local property settings.

You can also override any of the global settings defined in fabfile.py using ~/.sstk. For instance, if you want to change the default value for the AWS_HVM_AMI_ID setting, you can do:

```
{
  "clusters": {
     ...
  },
  "AWS_HVM_AMI_ID": "?"
}
```

AWS Setup
========

Configure boto to connect to AWS by adding your credentials to: ~/.boto
```
[Credentials]
aws_access_key_id = ?
aws_secret_access_key = ?
```
For more information about boto, please see: https://github.com/boto/boto

Use VPC
--------

Recent changes to EC2 security and networking make working with EC2 classic instead of using a VPC very difficult. Consequently, this toolkit only supports working with VPC.
For background on this issue, please see: https://aws.amazon.com/blogs/aws/amazon-ec2-update-virtual-private-clouds-for-everyone/

For a tutorial on setting up your VPC, see: http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/getting-started-create-vpc.html

The easiest way to integrate this toolkit with your VPC is to set a subnet ID in your `~/.sstk` file, such as:

```
"vpc_subnetid": "subnet-cfaaabe4"
```

You should also configure the subnet to auto-assign a public IP if you want to access the instances from remote servers.

Next, you'll need to setup a security group named solr-scale-tk (or update the fabfile.py to change the name).

At a minimum you should allow inbound TCP traffic to ports: 8983, 8984-8989, SSH, and 2181 (ZooKeeper). You should also allow all traffic between instances in the security group. However, it is your responsibility to review the security configuration of your cluster and lock it down appropriately.
You should ensure that the solr-scale-tk security group (or whatever you name it) has full TCP inbound traffic to all nodes (for ZooKeeper), which is accomplished by adding the security group as an inbound rule,
see: http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-network-security.html

You'll also need to create an keypair (using the Amazon console) named solr-scale-tk (you can rename the key used by the framework, see: AWS_KEY_NAME). After downloading the keypair file (solr-scale-tk.pem), save it to ~/.ssh/ and change permissions: chmod 600 ~/.ssh/solr-scale-tk.pem

You can name the security group and keypair whatever you want, however if you change the names, then you need to customize your `~/.sstk` file to override the defaults, such as:

```
"ssh_keyfile_path_on_local": "YOUR PEM FILE",
"AWS_KEY_NAME": "YOUR KEY NAME",
"AWS_SECURITY_GROUP":"solr-scale-tk-tjp",
```

Using the US West (N. California) Region
--------

By default, the toolkit launches instances in the us-east-1 region (N. Virginia). If you want to launch in the us-west-2 region (Oregon), then you need to override a few properties in your ~/.sstk file:

```
"region": "us-west-2"
"AWS_AZ":"us-west-2b",
"AWS_HVM_AMI_ID":"ami-c20ad5a2"
```

You'll also need to ensure the security group / keypair exist in the us-west-2 region as these are not visible across regions. In other words, if you created the security group / keypair in the us-east-1 region, and then moved to the west, then you'll need to re-create the security group / keypairs.

Overview
========

The solr-scale-tk framework works off the concept of a named "cluster". The named "cluster" concept is simply so that you don't need to worry about hostnames or IP addresses; the framework knows how to lookup hosts for a specific cluster. Behind the scenes, this uses Amazon tags to find instances and collect their host names.

Quick Demo

The easiest thing to do to ensure your environment is setup correctly and the script is working is to run:
```
fab demo:demo1,n=1
```
The demo command performs the following tasks in order:
1. Provisions one m3.medium instance in EC2
2. Configures one ZooKeeper server
3. Launches two Solr nodes in cloud mode (ports 8984 and 8985)
4. Creates a new collection named "demo" in SolrCloud; 1 shards, replication factor of 2
5. Indexes 10,000 synthetic documents in the demo collection

After verifying this works for you, take a moment to navigate to the Solr admin console and issue some queries against the collection. You can also go to the Solr admin console for the Solr instance that Logstash4Solr is using to index log messages from your SolrCloud nodes. After experimenting with the demo cluster, terminate the EC2 instance by doing: 
```
fab kill_mine
```
Fabric Commands

The demo command is cool, but to get the most out of the solr-scale-tk framework, you need to understand a little more about what's going on behind the scenes. Here's an example of how to launch a 3-node ZooKeeper ensemble and a 4-node SolrCloud cluster that talks to the ZooKeeper ensemble.
```
fab new_zk_ensemble:zk1,n=3 
fab new_solrcloud:cloud1,n=4,zk=zk1
fab new_collection:cluster=cloud1,name=test,shards=2,rf=2
```
Running these commands will take several minutes, but if all goes well, you'll have a collection named "test" with 2 shards and 2 replicas per shard in a 4-node SolrCloud cluster named "cloud1" and a 3-node ZooKeeper ensemble named "zk1" (7 EC2 instances in total). When this command finishes, you should see a message that looks similar to: 

Successfully launched new SolrCloud cluster cloud1; visit: SOLR_URL

Of course there is a lot going on here, so let's unpack these commands to get an idea of how the framework works.

new_zk_ensemble performs the following sub-commands for you:

new_ec2_instances(cluster='zk1', n=3, instance_type='m3.medium'): provisions 3 instances of our custom AMI on m3.medium VMs and tags each instance with the cluster name, such as "zk1"; notice that the type parameter used the default for ZK nodes: m3.medium

zk_ensemble(cluster='zk1', n=3): configures and starts ZooKeeper on each node in the cluster

All the nodes will be provisioned in the us-east-1 region by default. After the command finishes, you'll have a new ZooKeeper ensemble. Provisioning and launching a new ZK ensemble is separate from SolrCloud because you'll most likely want to reuse an ensemble between tests and it saves time to not have to re-create a ZooKeeper ensemble for each test. Your choice either way.

Next, we launch a SolrCloud cluster using the new_solrcloud command, which does the following:

new_ec2_instances(cluster='cloud1', n=4, instance_type='m3.medium'): provisions 4 instances of our custom AMI on m3.medium and tags each instance with the cluster name, such as "cloud1"; again the type uses the default m3.medium but you can override this by passing the instance_type='???' parameter on the command-line.

setup_solrcloud(cluster='cloud1', zk='zk1', nodesPerHost=1): configures and starts 1 Solr process in cloud mode per machine in the 'cloud1' cluster. The zkHost is determined from the zk parameter and all znodes are chroot'd using the cluster name 'cloud1'. If you're using larger instance types, then you can run more than one Solr process on a machine by setting the nodesPerHost parameter, which defaults to 1.

Lastly, we create a new collection named "test" in the SolrCloud cluster named "cloud1". At this point, you are ready to run tests.

Nuts and Bolts
========

Much of what the solr-scale-tk framework does is graceful handling of waits and status checking. For the most part, parameters have sensible defaults. Of course, parameters like number of nodes to launch don't have a sensible default, so you usually have to specify sizing type parameters. Overall, the framework breaks tasks into 2 phases:

Provisioning instances of our AMI
Configuring, starting, and checking services on the provisioned instances
The first step is highly dependent on Amazon Web Services. Working with the various services on the provisioned nodes mostly depends on SSH and standard Linux commands and can be ported to work with other server environments.
This two-step process implies that if step #1 completes successfully but an error / problem occurs in #2, that the nodes have already been provisioned and that you should not re-provision nodes. Let's look at an example to make sure this is clear. Specifically, imagine you get an error when running the new_solrcloud command. First you need to take note as to whether nodes have been provisioned. You will see green informational message about this in the console, such as:
** 2 EC2 instances have been provisioned **
If you see a message like this, then you know step 1 was successful and you only need to worry about correcting the problem and re-run step 2, which in our example would be running the solrcloud action. However, it is generally safe to just re-run the command (e.g. new_solrcloud) with the same cluster name as the framework will notice that the nodes are already provisioned and simply prompt you on whether it should re-use them.

Fabric Know-How

To see available commands, do:
```
fab -l
```
To see more information about a specific command, do:
```
fab -d <command>
```

Patching

Let's say you've spun up a cluster and need to patch the Solr core JAR file after fixing a bug. To do this, use the patch_jars command. Let's look at an example based on branch_4x. First, you need to build the JARs locally:
```
cd ~/dev/lw/projects/branch_4x/solr
ant clean example
cd ~/dev/lw/projects/solr-scale-tk
fab patch_jars:<cluster>,localSolrDir='~/dev/lw/projects/branch_4x/solr'
```
This will scp the solr-core-<VERS>.jar and solr-solrj-<VERS>.jar to each server, install them in the correct location for each Solr node running on the host, and then restart Solr. It performs this patch process very methodically so that you can be sure of the result. For example, after restarting, it polls the server until it comes back online to ensure the patch was successful (or not) before proceeding to the next server. Of course this implies the version value matches on your local workstation and on the server. Currently, we're using <VERS> == 4.7-SNAPSHOT.

The patch_jars command also supports a few other parameters. For example, let's say you only want to patch the core JAR on the first instance in the cluster:

```
fab patch_jars:<cluster>,localSolrDir='~/dev/lw/projects/branch_4x/solr',n=0,jars=core
```

Important Tips
========

The most important thing to remember is that you need to terminate your cluster when you are finished testing using the kill command. For instances, to terminate all 7 nodes created in our example above, you would do:

fab kill:cloud1

If you're not sure what clusters you are running, simply do:
fab mine

And, to kill all of your running instances, such as before signing off for the day, do:
fab kill_mine

The second most important thing to remember is that you don't want to keep provisioning new nodes. So if you try to run fab new_solrcloud:cloud1... and the nodes have already been provisioned for "cloud1", then you'll be prompted to decide if you are trying to create another cluster or whether you just intend to re-run parts of that command against the already provisioned nodes.

Fusion
========

Fusion provides the enterprise-grade capabilities needed to design, develop and deploy intelligent search apps at every level of your organization — at any scale. 

To get started, you can run the fusion_demo task to launch a single node cluster in EC2 which includes ZooKeeper, SolrCloud, and Fusion (API, UI, Connectors)

```
fab fusion_demo:cloud1
```

The demo launches an m3.large instance in the us-east-1b data center.

Alternatively, can run Fusion with your SolrCloud cluster by running the following additional steps after starting a cluster using the process described above.

1. Pull down the Fusion distribution from S3 and install it on all nodes in the specified cluster (e.g. cloud1):

```
fab fusion_setup:cloud1
```

This installs Fusion in /home/ec2-user/fusion. You only need to run fusion_setup once per cluster.

2. Start Fusion services on nodes in your cluster:

```
fab fusion_start:cloud1
```

This will start the Fusion API service on port 8765, the Fusion UI service on port 8764, and the connectors service on port 8763. Fusion will use the ZooKeeper and SolrCloud services setup using the toolkit.

After running fusion_start, you can direct your Web browser to the Fusion UI at http://host:8764

