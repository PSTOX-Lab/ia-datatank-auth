/**
 * Created by alexalex on 2025-03-07.
 *
 * Copyright 2025 PSTOX Lab Inc.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

@IsTest
private class AX360AuthProviderTest {
    private static final String OAUTH_TOKEN = 'testToken';
    private static final String STATE = 'mocktestState';
    private static final String REFRESH_TOKEN = 'refreshToken';
    private static final String STATE_TO_PROPOGATE  = 'testState';
    public static final String CALLBACK_URL = 'https://my.salesforce.com/services/authcallback/myid';


    private static Map<String,String> setupAuthProviderConfig () {
        Map<String,String> authProviderConfiguration = new Map<String,String>();

        authProviderConfiguration.put('Cerificate_Name__c', 'myid');
        authProviderConfiguration.put('Certificate_thumbprint__c', 'certThumb');
        authProviderConfiguration.put('Token_named_credentials__c', 'tenantNameCred');
        authProviderConfiguration.put('Tenant_ID__c', 'TOKEN_REMOTE_SITE');
        authProviderConfiguration.put('Client_ID__c', 'clientId');
        authProviderConfiguration.put('scope__c', 'scope');
        authProviderConfiguration.put('Callback_URL__c', CALLBACK_URL);
        authProviderConfiguration.put('State', STATE);
        return authProviderConfiguration;

    }

    // implementing a mock http response generator for concur
    public  class AX360MockHttpResponse implements HttpCalloutMock {


        public HTTPResponse respond(HTTPRequest req) {
            System.debug('< < < < < < - - - - - - - - - Request - - - - - - - - - - > > > > > > > >');
            System.debug(req);
            // Create a fake response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            res.setBody('');
            res.setStatusCode(200);
            return res;
        }
    }

    @IsTest
    static void testUserInfo() {
        Profile userProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User testUser = new User(
                FirstName = 'Test',
                LastName = 'User',
                Email = 'appuser@example.com',
                Username = 'appuser@example.test',
                Alias = 'apuser',
                TimeZoneSidKey = 'America/New_York',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                ProfileId = userProfile.Id,
                LanguageLocaleKey = 'en_US'
        );
        insert testUser;
        Auth.UserData authUser;
        System.runAs(testUser){
            AX360AuthProvider ax360 = new AX360AuthProvider();
            Map<String, String> authProviderConfiguration = setupAuthProviderConfig();
            Auth.AuthProviderTokenResponse response = new Auth.AuthProviderTokenResponse('AX360',
                    'token', 'refreshToken', 'state');
            authUser = ax360.getUserInfo(authProviderConfiguration, response);

        }

        Assert.areEqual('Test', authUser.FirstName, 'runs on a different user name');
        Assert.areEqual('en_US', authUser.locale, 'no match with location of en_Us');

    }

    @IsTest
    static void testGetCustomMetaDataType(){
        AX360AuthProvider ax360 = new AX360AuthProvider();
        String metaName = ax360.getCustomMetadataType();

        Assert.areEqual('AX360_Authentication_Setting__mdt', metaName, 'expected this: AX360_Authentication_Setting__mdt');
        System.debug(metaName);
    }

    @IsTest
    static void testInitiate(){
        Map<String,String> authProviderConfiguration = setupAuthProviderConfig();
        AX360AuthProvider ax360 = new AX360AuthProvider();
        String url = Url.getOrgDomainUrl().toExternalForm() + '/apex/AX360AuthPage';
        url = url + '?state=' + EncodingUtil.urlEncode(STATE_TO_PROPOGATE, 'utf-8') +
                '&callback=' + EncodingUtil.urlEncode(authProviderConfiguration.get('Callback_URL__c'), 'utf-8');
        PageReference expectedUrl =  new PageReference(url);

        PageReference actualUrl = ax360.initiate(authProviderConfiguration, STATE_TO_PROPOGATE);
        Assert.areEqual(expectedUrl.getUrl(), actualUrl.getUrl());
    }

    @IsTest
    static void testHandleCallback(){
        Map<String,String> authProviderConfiguration = setupAuthProviderConfig();
        AX360AuthProvider ax360 = new AX360AuthProvider();

        Map<String,String> queryParams = new Map<String,String>();
        queryParams.put('code','code');
        queryParams.put('state',authProviderConfiguration.get('State'));
        Auth.AuthProviderCallbackState cbState = new Auth.AuthProviderCallbackState(null,null,queryParams);

        Test.setMock(HttpCalloutMock.class, new AX360MockHttpResponse());

        Auth.AuthProviderTokenResponse tokenResp = ax360.handleCallback(authProviderConfiguration, cbState);
        Auth.AuthProviderTokenResponse expectedAuthProvResponse = new Auth.AuthProviderTokenResponse('myid', OAUTH_TOKEN, REFRESH_TOKEN, null);
    }
}