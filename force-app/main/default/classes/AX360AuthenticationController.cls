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
public with sharing class AX360AuthenticationController {
    public AX360AuthenticationController() {}

    public PageReference urlRedirection() {
        System.debug('urlRedirection');

        String state = EncodingUtil.urlDecode(ApexPages.currentPage().getParameters().get('state'), 'utf-8');
        String redirectUrl = EncodingUtil.urlDecode(ApexPages.currentPage().getParameters().get('callback'), 'utf-8');
        String code = EncodingUtil.urlEncode(EncodingUtil.base64Encode(Crypto.generateAesKey(128)), 'utf-8');
        PageReference page = new PageReference(redirectUrl + '?state=' + state +'&code=' + code);
        page.setRedirect(true);
        System.debug(state);
        System.debug(redirectUrl);
        System.debug(code);
        System.debug(page);
        return page;
    }
}