# ia-datatank-auth: Installation and configuration

In addition to the code, you need to prepare your organisation to install iA's DataTank Authentification provider.
You'll need the integration package from iA: the certificate and private key for authentication. In addition to that
you need some information provided by iA:
 * The certificate and private key for authentication provided in a password-less *.pfx file;
 * Your client ID;
 * Your API's URLs for both development and production;
 * Your Microsoft Azure's tenant ID;

## Preparation steps

Before installing and configuring the authentication provider, you'll need to perform a few preparation steps

### Necessary tools
 * Java's keytool, you can get this tool by downloading a JDK
 * [Salesforce's sf cli](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_install_cli.htm)
 * A version of openssl command line utility. Most Unix like operating system provide a version of OpenSSL, you should
check the package manager of your OS. For Windows and other OS, refer to the
[official list of OpenSSL binaries](https://github.com/openssl/openssl/wiki/Binaries).


### Import the certificate and private key provided by iA into a java Keystore

Because iA's *.pfx file (a pkcs12 file) doesn't have a password, and because java's keytool won't import a key that is
not protected by a password. We need to export and then re-import the certificate and private key into a password
protected pkcs12 file.

First, extract the certificate and private key into a PEM encoded file, when asked for a password, just hit _Enter_:

`openssl pkcs12 -in <pfx file name>.pfx -out certificate-and-key.pem -noenc`

Then, import the key and certificate into a new pkcs12 file, making sure to set a password when prompted. The password
doesn't need to be secure because this file will only be used for the conversion to JKS and it can be deleted after
the conversion. Also, keep the alias you set with the name parameter, you'll need it in the next step.

`openssl pkcs12 -export -in certificate-and-key.pem -out certificate-and-key.p12 -name <alias>`

The final step is to import the pkcs12 file in a jks file

`keytool -importkeystore -destkeystore certificate-and-key.jks -srckeystore certificate-and-key.p12 -srcstoretype PKCS12 -alias <alias>`

Before finalising this step, we need to calculate the thumbprint of this certificate. First, export the certificate in
a DER encoded file.

`openssl x509 -in certificate-and-key.pem -outform DER -out certificate-and-key.der`

Calculate the thumbprint and convert it in base64

`openssl dgst -sha256 -binary certificate-and-key.der | openssl base64 | tr -d '=' | tr '/+' '_-'`

On Windows you can replace the tr calls by saving the output of openssl to a file and executing a Powershell script:

```
$thumbprint = Get-Content thumbprint.b64 -Raw
$thumbprint = $thumbprint.Replace('+', '-').Replace('/', '_').Replace('=', '').Trim()
Write-Output $thumbprint
```

Keep this value around, you'll need it in the configuration steps.

At this point you can delete the *.pem, *.der and *.p12 files.

### Import the keystore in Salesforce's certificates

In setup, search for certificate, then click import. Chose the jks file created in the previous step and enter the password
you defined on the keystore.

If you get a 'Data not available error', you can open a case at Salesforce to be able to import the jks file, or you can
follow those steps to circumvent the error:

[https://lekkimworld.com/2018/07/03/issue-with-importing-keystore-into-salesforce/](https://lekkimworld.com/2018/07/03/issue-with-importing-keystore-into-salesforce/)

### Define an anonymous Named Credentials for Microsoft API

The authentication provider needs to call Microsoft Azure's authentication API. We use a Named Credential for that, it should
be defined with no authentication (Anonymous), the URL must be

 * [https://login.microsoftonline.com](https://login.microsoftonline.com)

### Deploy the code

If you have not connected your sandbox with sf:

`sf org login web --alias <sandbox alias>`

Deploy to your sandbox:

`sf project deploy start --target-org <sandbox alias>`

## Configuration

Once all the preparation steps completed, you can now create DataTank's authentication provider.

### Create the Authentication Provider

 * From Setup, search for _Auth. Providers_
 * Click "New"
 * In Provider Type select AX360AuthProvider
 * Give the Auth Provider a descriptive name, like datatank
 * Let Salesforce decide the suffix
 * For callback, enter [https://localhost](https://localhost) for now
 * For certificate name, enter the certificate alias you created in the preparation steps
 * For certificate thumbprint enter the value of the thumbprint calculated in the preparation steps
 * In Client ID, enter the client ID provided by iA
 * In Tenant ID, enter the tenant ID provided by iA
 * In Token named credentials, enter the name of the Named Credentials you created for Microsoft API in the preparation steps
 * In scope, enter the scope provided by iA
 * In Execute Registration As, select a valid Salesforce user. The user chosen is not important because the Authentication
provider does not have the code to register new users
 * Click save
 * Go at the bottom of the page, and copy the URL named Callback URL
 * Edit the connection provider, and replace the callback value with the URL copied in the previous step
 * Save the Authentication Provider again

### Configure DataTank's Named Credentials

 * In Setup, go to Named Credentials
 * Click in the dropdown button labeled _New_, select _New Legacy_
 * Give it a descriptive label, let Salesforce determine the name
 * Enter the URL provided by iA for their API, make sure that to add the path _/api/v1/_ is specified in the URL you enter
 * Leave Certificate blank
 * In Identity Type, chose _Per User_
 * In Authentication Protocol, select _OAuth 2.0_
 * In Authentication Provider, select the authentication provide you created in the previous step
 * For Scope, enter the Scope provided by iA
 * Leave all the other fields as is
 * Click Save
 * You should be redirected to a _Confirm External Access_ page, confirm the access
 * Salesforce should return you to the Named Credentials page, this time you should see your Salesforce Username in the
_Administration Authentication Status_ field

### Grant access to DataTank's Named Credentials to the user that will be running the batch

Once you have determined which user(s) needs to use the DataTank API, they each have to configure their name credentials
in their user's settings.

 * From a user's settings, select _Authentication Settings for External Systems_
 * Click _New_
 * Make sure that _Named Credentials_ is selected in _External System Definition_ and the new Named Credentials is
selected in _Named Credential_
 * The user should select her user in _User_
 * Make sure the field _Start Authentication Flow on Save_ is selected
 * Click Save
 * You should be redirected to a _Confirm External Access_ page, confirm the access

### Test the Named Credentials

 * Go into the Developer Console
 * Open Execute Anonymouse Window
 * Execute the following code, making sure that Open Log is selected
```
Http http = new Http();
HttpRequest req = new HttpRequest();
req.setMethod('GET');
req.setEndpoint('callout:<Your_Name_Credentals>/accounts/repcodes');
HttpResponse resp = http.send(req);
System.debug(resp.getStatus());
System.debug(resp.getBody());
```
 * In the logs, you should see a 200 status code, with a list of rep codes