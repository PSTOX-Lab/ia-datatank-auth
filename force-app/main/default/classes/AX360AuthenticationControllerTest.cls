/**
 * Created by benoitde on 2025-04-02.
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

@isTest
private class AX360AuthenticationControllerTest {

    @isTest
    static void testUrlRedirection() {
        // Set test parameters
        String stateValue = 'sample-state';
        String callbackUrl = 'https://example.com/callback';

        Test.startTest();

        // Simulate page parameters
        Test.setCurrentPage(new PageReference('/someDummyPage'));

        ApexPages.currentPage().getParameters().put('state', EncodingUtil.urlEncode(stateValue, 'UTF-8'));
        ApexPages.currentPage().getParameters().put('callback', EncodingUtil.urlEncode(callbackUrl, 'UTF-8'));

        // Create controller instance and call method
        AX360AuthenticationController controller = new AX360AuthenticationController();
        PageReference resultPage = controller.urlRedirection();

        Test.stopTest();

        // Verify result
        System.assertNotEquals(null, resultPage, 'PageReference should not be null');
        Map<String, String> m = resultPage.getParameters();
        System.assert(resultPage.getUrl().startsWith(callbackUrl), 'Redirect URL should start with callback');
        System.assert(m.containsKey('state'), 'Redirect URL should contain state');
        System.assert(m.containsKey('code'), 'Redirect URL should contain encoded code');
    }
}