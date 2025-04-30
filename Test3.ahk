; File: duckgpt_prompt_tool.ahk
#Include JSON.ahk

; Configuration
global API_Endpoint := "https://duckgpt.live/chat/?prompt="

global PromptPresets := {
    "Rephrase": "Rephrase the following text or paragraph to ensure clarity, conciseness, and a natural flow. The revision should preserve the tone, style, and formatting of the original. Respond without comments or elaboration. Text to rephrase: ",
    "Agent": "I work as technical chat support agent for web hosting company. Help me with refining my responses. Please refine the following text according to these guidelines:- **Tone & Clarity:** Use simple, empathetic. Avoid jargon. Use a customer service tone. Do not use 'Unfortunately.' Ensure responses are supportive and engaging, making it easy for customers to understand.- The revision should preserve the tone, style, and formatting of the original. **Currency & Dates:** Use '$' for currency. Format dates as MMM DD, YYYY (e.g., Oct 29, 2010). **Links:** Provide links explicitly. Don't include 'Thank you' at the end. Respond without comments or elaboration. Text to rephrase:",
    "Answer": "Answer the following question concisely in plain text without markdown:",
    "Expand": "Expand the following text, preserving the tone, style, and formatting of the original. Respond without comments:",
    "Give in steps": "Provide the following text in steps in plain text without markdown:",
    "Summarize": "Summarize the following text concisely:"
}

; Hotkeys
^i::showPromptMenu()
^'::
Send, ^a
processAndSendPrompt("Rephrase")
return

; Menu
showPromptMenu() {
    static menuBuilt := false
    if (!menuBuilt) {
        Menu, PromptMenu, UseErrorLevel
        Menu, PromptMenu, DeleteAll
        for label, _ in PromptPresets
            Menu, PromptMenu, Add, %label%, onPromptSelected
        menuBuilt := true
    }
    Menu, PromptMenu, Show
    if (ErrorLevel)
        MsgBox, 48, Menu Error, Failed to display prompt menu.
}

onPromptSelected:
processAndSendPrompt(A_ThisMenuItem)
return

; Main function
processAndSendPrompt(presetLabel) {
    try {
        promptTemplate := PromptPresets[presetLabel]
        if (!promptTemplate) {
            MsgBox, 48, Prompt Error, Invalid prompt preset: %presetLabel%
            return
        }

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

        logDebug("----------------------------------------------------------------------------------------------")
        logDebug("User Input: " . userInput)

        finalPrompt := promptTemplate . " " . userInput
        logDebug("Final Prompt: " . finalPrompt)

        aiResponse := fetchDuckGPT(finalPrompt)

        if (!aiResponse) {
            MsgBox, 16, API Error, Failed to retrieve a valid response from the AI.
            Clipboard := clipboardBackup
            return
        }

        logDebug("Raw AI Response: " . aiResponse)

        cleanedResponse := cleanAIResponse(aiResponse)
        logDebug("Cleaned Response: " . cleanedResponse)

        Clipboard := cleanedResponse
        Send, ^v
        Sleep, 2000
        Clipboard := clipboardBackup
    } catch e {
        MsgBox, 16, Unexpected Error, % "Something went wrong:`n" . e.Message
        Clipboard := clipboardBackup
    }
}

; API fetch
fetchDuckGPT(prompt) {
    encodedPrompt := uriEncode(prompt)
    url := buildDuckGPTUrl(encodedPrompt)
    logDebug("Encoded URL: " . url)

    http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    Loop, 2 {
        try {
            http.Open("GET", url, false)
            http.Send()
            if (http.Status = 200) {
                responseText := http.ResponseText
                logDebug("Raw Response Text: " . responseText)
                try {
                    json := JSON.Load(responseText)
                    return json.response
                } catch e {
                    logDebug("JSON Parsing Error: " . e.Message)
                    throw Exception("Failed to parse JSON response.")
                }
            } else {
                logDebug("HTTP Error Status: " . http.Status)
            }
        } catch e {
            logDebug("HTTP Exception: " . e.Message)
            Sleep, 300
        }
    }
    throw Exception("Failed to fetch API response after retrying.")
}

; Helpers
buildDuckGPTUrl(encodedPrompt) {
    return API_Endpoint . encodedPrompt
}

cleanAIResponse(text) {
    clean := Trim(text)
    clean := StrReplace(clean, "`r`n", "`n")
    clean := StrReplace(clean, "`r", "`n")
    clean := RegExReplace(clean, "`n{2,}", "`n")
    clean := RegExReplace(clean, "[\x00-\x08\x0B\x0C\x0E-\x1F]") ; Remove control characters
    clean := RegExReplace(clean, " {2,}", " ")

    ; Fix common bad UTF-8 decoding artifacts
    clean := StrReplace(clean, "â€™", "'")
    clean := StrReplace(clean, "â€œ", """")
    clean := StrReplace(clean, "â€", """")
    clean := StrReplace(clean, "â€“", "-")
    clean := StrReplace(clean, "â€”", "-")

    return clean
}

uriEncode(uri, RE := "[0-9A-Za-z]") {
    VarSetCapacity(Var, StrPut(uri, "UTF-8") + 1, 0)
    StrPut(uri, &Var, "UTF-8")
    NumPut(0, &Var + StrPut(uri, "UTF-8") - 1, "UChar")
    result := ""
    while code := NumGet(Var, A_Index - 1, "UChar")
        result .= (chr := Chr(code)) ~= RE ? chr : Format("%%%02X", code)
    return result
}

logDebug(msg) {
    static debugEnabled := true
    if (!debugEnabled)
        return
    FormatTime, now,, yyyy-MM-dd HH:mm:ss
    logMsg := "[" . now . "] " . msg . "`n"
    FileAppend, %logMsg%, ./debug.log
}
