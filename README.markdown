IPD is a simple patient registration application written in Ruby on Rails
and is intended as a web front end for OpenMRS. 

OpenMRS® is a community-developed, open-source, enterprise electronic medical 
record system framework. We've come together to specifically respond to those 
actively building and managing health systems in the developing world, where 
AIDS, tuberculosis, and malaria afflict the lives of millions. Our mission is 
to foster self-sustaining health information technology implementations in 
these environments through peer mentorship, proactive collaboration, and a code 
base that equals or surpasses proprietary equivalents. You are welcome to come 
participate in the community, whether by implementing our software, or 
contributing your efforts to our mission!

IPD was built by Baobab Health and Partners in Health in
Malawi, Africa. It is licensed under the Mozilla Public License.


===================================================================================================================
ADMISSION, DISCHARGE AND TRANSFER(ADT) SYSTEM CONFIGURATION
===================================================================================================================
Below are some simple steps to follow when you want to setup ADT.

Open your terminal
Get a source code from github by typing "git clone git@github.com:BaobabHealthTrust/IPD.git"
Enter into the root of your application by typing "cd IPD"
Type "cp config/application.yml.example config/application.yml"
Type "cp config/database.yml.example config/database.yml"
Note: Open config/database.yml and edit the file. Provide any database name to be used in your application. Do not forget to provide mysql password in the same file.
Type "script/runner script/initial_database_setup.sh development mpc". Please be patient while the script is running. This may take some time.
Type "sudo bundle install"
After completing the above steps, you may now run the application by typing "script/server"

Open your browser on the following address"http://0.0.0.0:3000"
Username : admin
password : test
Workstation Location : 721
Note: You can change the default port of the application by passing -p option
e.g "script/server -p 3001"

With the above steps, you have managed to setup the application. BUT ADT talks with Radiology system when capturing patient investigations so you just need to follow some steps as below.
Open new terminal 
Type "git clone git@github.com:BaobabHealthTrust/Radiology.git"
Type "cd Radiology"
Type "cp config/application.yml.example config/application.yml"
Type "cp config/database.yml.example config/database.yml"
Edit config/database.yml. The database name should be the same as what ADT is using

ONE MORE THING
Open config/application.yml file. 
Change value of rad_url to point to url that the Radiology system will be running.
Change value of ipd_url to point to url that the ADT system will be running.
===================================================================================================================
