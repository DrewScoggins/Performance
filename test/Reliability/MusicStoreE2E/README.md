# JMeter Setup
- Install Java (https://www.java.com/en/ and click the download link)
- Install jMeter
    - Go to http://jmeter.apache.org/download_jmeter.cgi
    - click on apache-jmeter-2.13.zip link under the Binaries heading to download the JMeter binaries
    - Save the zip file to c:\jMeter
    - Unzip the file by right clicking the zip file and selecting "Extract All"

# Running JMeter
- In a command window, go to the JMeter bin folder (apache-jmeter-2.13\bin)
- Run:  jmeter.bat

# To Initialize the MusicStore database with user accounts:
- Once the JMeter UI has opened, click the File Open icon and open MusicStoreUserRegistration.jmx
- Click on the Run Time Variables element at the top of the test plan and set the Host and Port variables
- click on the Run button.
    
# To run the multi user scenario:
- In the JMeter UI, click the File Open icon and open MusicStoreShoppingCartScenarioPerThreadUser.jmx
- Click on the Run Time Variables element at the top of the test plan and set the Host, Port, NumClients variables
- Click on the Run button.

# Running JMeter with a single admin user (does not require creating user accounts first)
- In a command window, go to the JMeter bin folder (apache-jmeter-2.13\bin)
- Run:  jmeter.bat
- Once the JMeter UI has opened, click the File Open icon and open MusicStoreShoppingCartScenario.jmx
- Click on the Run Time Variables element at the top of the test plan and set the Host, Port variables
- In the Run Time Variables element at the top of the test plan NumClients MAKE SURE the number of clients is 1
- click on the Run button.