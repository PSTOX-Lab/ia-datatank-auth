/**
 * Created by benoitde on 2025-02-17.
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
public with sharing class AX360AuthProvider extends Auth.AuthProviderPluginClass {
    public static final String CALLBACK_URL = AX360_Authentication_Setting__mdt.Callback_URL__c.getDescribe().name;
    public static final String TOKEN_NAMED_CREDENTIALS = AX360_Authentication_Setting__mdt.Token_named_credentials__c.getDescribe().name;
    public static final String CERTIFICATE_NAME = AX360_Authentication_Setting__mdt.Cerificate_Name__c.getDescribe().name;
    public static final String CERTIFICATE_THUMBPRINT = AX360_Authentication_Setting__mdt.Certificate_thumbprint__c.getDescribe().name;
    public static final String TENANT_ID =  AX360_Authentication_Setting__mdt.Tenant_ID__c.getDescribe().name;
    public static final String CLIENT_ID =  AX360_Authentication_Setting__mdt.Client_ID__c.getDescribe().name;
    public static final String SCOPE =  AX360_Authentication_Setting__mdt.scope__c.getDescribe().name;

    public static final String ASSERTION_TYPE = EncodingUtil.urlEncode('urn:ietf:params:oauth:client-assertion-type:jwt-bearer', 'UTF-8');

    public String getCustomMetadataType() {
        String metaName = AX360_Authentication_Setting__mdt.getSObjectType().getDescribe().name;
        return metaName;
    }

    public Auth.UserData getUserInfo(Map<String, String> authProviderConfiguration, Auth.AuthProviderTokenResponse response) {
        Auth.UserData user = new Auth.UserData(UserInfo.getUserName(), UserInfo.getFirstName(), UserInfo.getLastName(), UserInfo.getName(),
                UserInfo.getUserEmail(), null, UserInfo.getUserName(), UserInfo.getLocale(), 'Croesus', null, new Map<String, String>());
        return user;
    }

    public Auth.AuthProviderTokenResponse handleCallback(Map<String, String> authProviderConfiguration, Auth.AuthProviderCallbackState callbackState) {
        System.debug('handleCallback');
        string token = getToken(authProviderConfiguration);

        String refreshToken = EncodingUtil.urlEncode(EncodingUtil.base64Encode(Crypto.generateAesKey(128)), 'utf-8');

        Auth.AuthProviderTokenResponse authResp = new Auth.AuthProviderTokenResponse('AX360', token, refreshToken, callbackState.queryParameters.get('state'));
        return authResp;
    }

    public PageReference initiate(Map<String, String> authProviderConfiguration, String stateToPropagate) {
        String url = Url.getOrgDomainUrl().toExternalForm() + '/apex/AX360AuthPage';
        url = url + '?state=' + EncodingUtil.urlEncode(stateToPropagate, 'utf-8') +
                '&callback=' + EncodingUtil.urlEncode(authProviderConfiguration.get(CALLBACK_URL), 'utf-8');
        System.debug('url: ' + url);
        return new PageReference(url);
    }

    public override Auth.OAuthRefreshResult refresh(Map<String,String> authProviderConfiguration, String refreshToken) {
        System.debug('refresh');
        String token = getToken(authProviderConfiguration);

        refreshToken = EncodingUtil.urlEncode(EncodingUtil.base64Encode(Crypto.generateAesKey(128)), 'utf-8');

        Auth.OAuthRefreshResult result = new Auth.OAuthRefreshResult(token, refreshToken);

        return result;
    }


    private String getToken(Map<String, String> authProviderConfiguration) {
        System.debug('getToken');
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:' + authProviderConfiguration.get(TOKEN_NAMED_CREDENTIALS) + '/' + authProviderConfiguration.get(TENANT_ID) + '/oauth2/v2.0/token');
        request.setMethod('POST');
        System.debug('request: ' + request);

        // Set Content-Type header
        request.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        String jwt = generateJWT(authProviderConfiguration);

        String body = 'grant_type=client_credentials' +
                '&client_assertion_type=' + ASSERTION_TYPE +
                '&scope=' + EncodingUtil.urlEncode(authProviderConfiguration.get(SCOPE), 'UTF-8') +
                '&client_id=' + EncodingUtil.urlEncode(authProviderConfiguration.get(CLIENT_ID), 'UTF-8') +
                '&client_assertion=' + EncodingUtil.urlEncode(jwt, 'UTF-8');
        request.setBody(body);

        // Send the request
        Http http = new Http();

        HttpResponse res;
        try {
            res = http.send(request);
            System.debug('Response Status: ' + res.getStatusCode());
            String respBody = res.getBody();
            if (res.getStatusCode() >= 400) {
                System.debug('Error response: ' + respBody);
                return 'COULD NOT GET TOKEN';
            } else {
                Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(respBody);
                return m.get('access_token').toString();
            }
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
        }

        return null;
    }

    private String generateJWT(Map<String, String> authProviderConfiguration) {
        System.debug('generateJWT');
        Map<String, String> header = new Map<String, String>{
                'alg'=> 'RS256',
                'x5t#S256'=> authProviderConfiguration.get(CERTIFICATE_THUMBPRINT),
                // 'kid' => 'PoVKeirIOvmTyLQ9G9BenBwos7k',
                'typ'=> 'JWT'
        };
        String headerJson = JSON.serialize(header);

        Long now = DateTime.now().getTime() / 1000L;

        Map<String, Object> body = new Map<String, Object>{
                'aud' => 'https://login.microsoftonline.com/' + authProviderConfiguration.get(TENANT_ID) + '/oauth2/v2.0/token',
                'iss' => authProviderConfiguration.get(CLIENT_ID),
                'sub' => authProviderConfiguration.get(CLIENT_ID),
                'jti' => UUID.randomUUID(),
                'iat' => now - 5,
                'nbf' => now - 5,
                'exp' => now + 60L,
                'scope' => authProviderConfiguration.get(SCOPE)
        };
        String bodyJson = JSON.serialize(body);

        String headerB64 = base64UrlEncode(Blob.valueOf(headerJson));
        String bodyB64 = base64UrlEncode(Blob.valueOf(bodyJson));

        String signatureB64;
        if (!Test.isRunningTest()) {
            Blob signatureBlob = Crypto.signWithCertificate('RSA-SHA256', Blob.valueOf(headerB64 + '.' + bodyB64), authProviderConfiguration.get(CERTIFICATE_NAME));
            signatureB64 = base64UrlEncode(signatureBlob);
        } else {
            signatureB64 = base64UrlEncode(Blob.valueOf('[No signature]'));
        }

        String jwt = headerB64 + '.' + bodyB64 + '.' + signatureB64;

        return jwt;
    }

    private static String base64UrlEncode(Blob input) {
        String b64 = EncodingUtil.base64Encode(input);
        return b64.replace('+', '-').replace('/', '_').replaceAll('=+$', '');
    }
}