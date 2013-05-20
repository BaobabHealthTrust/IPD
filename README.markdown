ADT is a simple patient registration application written in Ruby on Rails
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

ADT was built by Baobab Health and Partners in Health in
Malawi, Africa. It is licensed under the Mozilla Public License.



<b>ADMISSION, DISCHARGE AND TRANSFER(ADT) SYSTEM CONFIGURATION</b><br />
Below are some simple steps to follow when you want to setup ADT.

Open your terminal<br />
Get a source code from github by typing <b>git clone git@github.com:BaobabHealthTrust/IPD.git</b><br />
Enter into the root of your application by typing "<b>cd IPD</b><br />"
Type <b>cp config/application.yml.example config/application.yml</b><br />
Type <b>cp config/database.yml.example config/database.yml </b><br />
Note: Open config/database.yml and edit the file. Provide any database name to be used in your application. Do not forget to provide mysql password in the same file </b><br />.
Type <b>script/runner script/initial_database_setup.sh development mpc</b>. Please be patient while the script is running. This may take some time</b><br />.
Type <b>sudo bundle install <br />
After completing the above steps, you may now run the application by typing <b>script/server </b><br />

Open your browser on the following address"http://0.0.0.0:3000" </b><br />
<b>Username : admin </b><br />
<b>password : test </b><br />
<b>Workstation Location : 721 </b><br />
Note: You can change the default port of the application by passing -p option
e.g "script/server -p 3001" <br />

With the above steps, you have managed to setup the application. BUT ADT talks with Radiology system when capturing patient investigations so you just need to follow some steps as below </b><br />.
Open new terminal  <br />
Type <b>git clone git@github.com:BaobabHealthTrust/Radiology.git </b><br />
Type <b>cd Radiology" </b><br />
Type <b>cp config/application.yml.example config/application.yml </b><br />
Type <b>cp config/database.yml.example config/database.yml </b><br />
Edit config/database.yml. The database name should be the same as what ADT is using <br />

ONE MORE THING<br />
Open config/application.yml file. <br />
Change value of rad_url to point to url that the Radiology system will be running.<br />
Change value of ipd_url to point to url that the ADT system will be running.<br />

