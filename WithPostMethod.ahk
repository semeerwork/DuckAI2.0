; File: duckgpt.ahk
#Include JSON.ahk

; Configuration
global API_Endpoint := "https://your-worker-domain.example.com/duckchat/v1/chat"

; Preset prompts for different types of tasks
global PromptPresets := {
    "SimpleRephrase": "Rephrase :",
    "Rephrase": "Rephrase the following text or paragraph to ensure clarity, conciseness, and a natural flow. The revision should preserve the tone, style, and formatting of the original. Respond without comments or elaboration. Text to rephrase:",
    "Agent": "I work as technical chat support agent for web hosting company. Help me with refining my responses. Text to rephrase:",
    "Answer": "Answer the following question concisely in plain text without markdown:",
    "Expand": "Expand the following text. Preserve the tone, style, and formatting of the original. Respond without comments:",
    "GiveInSteps": "Provide the following text in steps in plain text without markdown:",
    "Summarize": "Summarize the following text concisely:"
}

; Hotkeys
^i::showPromptMenu()
^'::
    Send, ^a
    processAndSendPrompt("SimpleRephrase")
return

; Menu creation and display
showPromptMenu() {
    global PromptPresets
    static menuBuilt := false
    if (!menuBuilt) {
        for label, _ in PromptPresets
            Menu, PromptMenu, Add, %label%, onPromptSelected
        menuBuilt := true
    }
    Menu, PromptMenu, Show
    if (ErrorLevel)
        MsgBox, 48, Menu Error, Failed to display prompt menu.
}

; Handle menu item selection
onPromptSelected:
    processAndSendPrompt(A_ThisMenuItem)
return

; Main logic: capture clipboard, send to API, replace clipboard with response
processAndSendPrompt(presetLabel) {
    global PromptPresets, API_Endpoint
    clipboardBackup := ClipboardAll
    Clipboard := ""
    Send, ^c
    ClipWait, 3

    userInput := Clipboard
    if (!Trim(userInput)) {
        MsgBox, 48, Clipboard Empty, Please select and copy some text first.
        Clipboard := clipboardBackup
        return
    }

    promptTemplate := PromptPresets[presetLabel]
    finalPrompt := promptTemplate . " " . userInput

    aiResponse := fetchDuckGPT(finalPrompt)
    if (!aiResponse) {
        MsgBox, 16, API Error, Failed to retrieve a valid response from the AI.
        Clipboard := clipboardBackup
        return
    }

    cleanedResponse := cleanAIResponse(aiResponse)
    Clipboard := cleanedResponse
    Send, ^v
    Sleep, 2000
    Clipboard := clipboardBackup
}

; Send POST request to API endpoint
fetchDuckGPT(prompt) {
    global API_Endpoint
    http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    http.SetTimeouts(5000, 5000, 10000, 10000)
    http.Open("POST", API_Endpoint, false)
    http.SetRequestHeader("Content-Type", "application/json; charset=utf-8")

    payload := JSON.Dump({ prompt: prompt })
    http.Send(payload)

    if (http.Status != 200)
        return ""

    try {
        json := JSON.Load(http.ResponseText)
    } catch {
        return ""
    }

    if (json.HasKey("response"))
        return json.response

    return ""
}

; Clean AI response: remove extra spaces, newlines, invalid characters
cleanAIResponse(text) {
    clean := Trim(text)
    clean := StrReplace(clean, "`r`n", "`n")
    clean := StrReplace(clean, "`r", "`n")
    clean := RegExReplace(clean, "`n{2,}", "`n")
    clean := RegExReplace(clean, "[\x00-\x08\x0B\x0C\x0E-\x1F]", "")
    clean := RegExReplace(clean, " {2,}", " ")

    ; Fix common UTF-8 artifacts
    clean := StrReplace(clean, "â€™", "'")
    clean := StrReplace(clean, "â€œ", '"')
    clean := StrReplace(clean, "â€", '"')
    clean := StrReplace(clean, "â€“", "-")
    clean := StrReplace(clean, "â€”", "-")

    return clean
}
