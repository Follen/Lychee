# Palette UI wowdoc evidence

## Evidence baseline

- sourceId: `wow-ui-source`
- product: `retail`
- requestedRef / matchedTag: `12.1.0`
- resolvedCommit: `31c7f7b9cc79e56c986b365c06a6afbcf3c9177b`

## Exact references

### Search Atlas and texture API

- `Interface/AddOns/Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml:212`

  ```xml
  <Texture name="$parentSearchIcon" atlas="common-search-magnifyingglass" useAtlasSize="false" parentKey="searchIcon">
  ```

- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleTextureBaseAPIDocumentation.lua:366`

  ```text
  Name = "SetAtlas"
  atlas: textureAtlas
  useAtlasSize: bool, Default = false
  SecretArguments = "AllowedWhenTainted"
  ```

Lychee therefore uses `searchIcon:SetAtlas("common-search-magnifyingglass", false)` with the verified Atlas name and argument shape.

### Native untemplated EditBox

- `Interface/AddOns/Blizzard_PTRFeedback/Blizzard_PTRFeedback_Frames.lua:117`

  ```lua
  questionFrame.EditBox = CreateFrame("EditBox", nil, questionFrame.EditBoxBackground)
  questionFrame.EditBox:SetAllPoints(questionFrame.EditBoxBackground)
  questionFrame.EditBox:SetTextInsets(5, 5, 5, -5)
  questionFrame.EditBox:SetAutoFocus(false)
  ```

- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleEditBoxAPIDocumentation.lua:616`: `SetAutoFocus` accepts one non-nil `bool`.
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleEditBoxAPIDocumentation.lua:915`: `SetTextInsets` accepts four non-nil `uiUnit` arguments.

This supports Lychee's native `CreateFrame("EditBox", nil, container)` without `InputBoxTemplate`.

### ScrollFrame and bounded scale

- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScrollFrameAPIDocumentation.lua:91`: `SetScrollChild(scrollChild: SimpleFrame)`; protected and allowed when untainted.
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScrollFrameAPIDocumentation.lua:103`: `SetVerticalScroll(offset: uiUnit)`; protected and allowed when untainted.
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua:95`: `EnableMouseWheel(enable: bool)`; protected, secret arguments not allowed.
- `Interface/AddOns/Blizzard_AccountStore/Blizzard_AccountStoreCardTemplates.lua:105`: `AccountStoreBaseCardMixin:OnMouseWheel(delta)` confirms the callback shape.
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua:1470`: `SetScale(scale: number)`; protected and allowed when untainted.
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua:286` and `:137`: `GetWidth()` and `GetHeight()` return `uiUnit`.
- `Interface/AddOns/Blizzard_SharedXML/Backdrop.xml:5`: `BackdropTemplate` exists in the fixed Retail snapshot.
- `Interface/AddOns/Blizzard_GameTooltip/Mainline/GameTooltip.xml:249`: `GameTooltip` exists in the fixed Retail snapshot.

All affected frames are created and owned by Lychee. Palette opening is rejected in combat and entering combat closes it, so these protected geometry calls remain on the existing out-of-combat path. The implementation registers no resize polling or `OnUpdate`; bounded scale is applied when the Palette opens.

## Validation command

```powershell
wowdoc validate --path package/Lychee --source wow-ui-source --product retail --ref 12.1.0
```
