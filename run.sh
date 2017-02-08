#!/bin/bash

# set passed in dir to variable
path=$1
key=$2
secret=$3

# determine whether chef-cient is installed
if (which chef-client); then
  echo installing knife ec2
  sudo /opt/chef/embedded/bin/gem install knife-ec2
else
  echo installing chef-client
  curl -L https://www.opscode.com/chef/install.sh | bash
  echo installing knife ec2
  sudo /opt/chef/embedded/bin/gem install knife-ec2
fi

# change directory to path
cd $path

# create knife.rb file
rm knife.rb
touch knife.rb

# populate knife.rb file
cat <<EOT >> knife.rb
current_dir = File.dirname(__FILE__)
log_level                :info
log_location             STDOUT
node_name                "stelligent"
client_key               "#{current_dir}/stelligent.pem"
chef_server_url          "https://ec2-52-205-233-2.compute-1.amazonaws.com/organizations/stelligent"
cookbook_path            ["#{current_dir}/../cookbooks"]
EOT
echo knife[:aws_access_key_id] = "'$2'" >> knife.rb
echo knife[:aws_secret_access_key] = "'$3'" >> knife.rb

# grab self signed cert from chef server
knife ssl fetch

# deploy webserver via knife ec2 command
knife ec2 server create -r 'recipe[webserver]' -I 'ami-0b33d91d' -f 't2.micro' -g 'sg-30ea8d4c' --subnet subnet-31a6a378 -N 'webserver' -x 'ec2-user' -S 'stelligent-webserver' -i $path'/stelligent-webserver.pem'

# while loop to make sure that the webserver is up
while ! knife ec2 server list|grep -i webserver|grep -i running
  do
    sleep 5
done

# set public IP of server to variable
ip=`knife ec2 server list|grep -i webserver|grep -i running|awk '{print $3}'`

# let user know what IP to hit to access webpage
echo "Please navigate to "$ip" in order to access the webpage!"
