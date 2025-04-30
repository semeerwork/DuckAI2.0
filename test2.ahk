; File: duckgpt_prompt_tool.ahk
#Include JSON.ahk
Global API_Endpoint := "https://duckgpt.live/chat/?prompt="
Global PromptPresets := {
    "Rephrase": "Rephrase the following text or paragraph to ensure clarity, conciseness, and a natural flow. The revision should preserve the tone, style, and formatting of the original. Respond without comments or elaboration. Text to rephrase: ",
    "Agent": "I work as technical chat support agent for web hosting company. help me with refining my responses. Please refine the following text according to these guidelines:- **Tone & Clarity:** Use simple, empathetic. Avoid jargon. Use a customer service tone. Do not use 'Unfortunately.' Ensure responses are supportive and engaging, making it easy for customers to understand.- The revision should preserve the tone, style, and formatting of the original. **Currency & Dates:** Use '$' for currency. Format dates as MMM DD, YYYY (e.g., Oct 29, 2010). **Links:** Provide links explicitly. Don't include 'Thank you' at the end. Respond without comments or elaboration. Text to rephrase:",
    "Answer": "Answer the following question concisely in plain text without markdown:",
    "Expand": "Expand the following text, The revision should preserve the tone, style, and formatting of the original, Respond without comments:",
    "Give in steps": "Provide following text in steps in plain text without markdown:",
    "Summarize": "Summarize the following text concisely:"
}

Global _debug := true

^i::ShowPromptMenu()
^'::
Send, ^a
SendProcessedPrompt("Rephrase")
return

ShowPromptMenu() {
    Menu, PromptMenu, UseErrorLevel
    Menu, PromptMenu, DeleteAll
    For label, _ in PromptPresets
        Menu, PromptMenu, Add, %label%, OnPromptSelected
    Menu, PromptMenu, Show
    if (ErrorLevel)
        MsgBox, 48, Menu Error, Failed to display prompt menu.
}

OnPromptSelected:
SendProcessedPrompt(A_ThisMenuItem)
Return

SendProcessedPrompt(PresetLabel) {
    Try {
        PromptTemplate := PromptPresets[PresetLabel]
        If (!PromptTemplate) {
            MsgBox, 48, Prompt Error, Invalid prompt preset: %PresetLabel%
            Return
        }

        clipboardBackup := ClipboardAll
        Clipboard := ""
        Send, ^c
        ClipWait, 3
        userInput := Clipboard

        If (!Trim(userInput)) {
            MsgBox, 48, Clipboard Empty, Please select and copy some text first.
            Clipboard := clipboardBackup
            Return
        }
        LogDebug("----------------------------------------------------------------------------------------------")
        LogDebug("----------------------------------------------------------------------------------------------")
        LogDebug("User Input: " . userInput)
        finalPrompt := PromptTemplate . " " . userInput
        LogDebug("Final Prompt: " . finalPrompt)

        aiResponse := FetchDuckGPT(finalPrompt)

        If (!aiResponse) {
            MsgBox, 16, API Error, Failed to retrieve a valid response from the AI.
            Clipboard := clipboardBackup
            Return
        }

        LogDebug("JSONed AI Response: " . aiResponse)
        clean := CleanAIResponse(aiResponse)
        LogDebug("Cleaned AI Response: " . clean)

        Clipboard := clean
        Send, ^v
        Sleep, 2000
        Clipboard := clipboardBackup
    } Catch e {
        MsgBox, 16, Unexpected Error, % "Something went wrong:`n" . e.Message
        Clipboard := clipboardBackup
    }
}

FetchDuckGPT(prompt) {
    encodedPrompt := UriEncode(prompt)
    url := API_Endpoint . encodedPrompt
    LogDebug("Encoded URL: " . url)

    http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    Loop, 2 {
        Try {
            http.Open("GET", url, false)
            http.Send()
            If (http.Status = 200) {
                responseText := http.ResponseText
                LogDebug("Raw Response Text: " . responseText)
                json := JSON.Load(responseText)
                Return json.response
            } else {
                LogDebug("HTTP Error Status: " . http.Status)
            }
        } Catch e {
            LogDebug("Exception in HTTP Request: " . e.Message)
            Sleep, 300
        }
    }
    MsgBox, 16, Network Error, Failed to get a response from API after retrying.
    Return ""
}

CleanAIResponse(text) {
    clean := Trim(text)
    clean := StrReplace(clean, "`r`n", "`n")
    clean := StrReplace(clean, "`r", "`n")
    clean := RegExReplace(clean, "`n{2,}", "`n")
    clean := StrReplace(clean, "â€™", "'")
    clean := RegExReplace(clean, "[\x00-\x08\x0B\x0C\x0E-\x1F]")
    clean := RegExReplace(clean, " {2,}", " ")
    Return clean
}

UriEncode(Uri, RE := "[0-9A-Za-z]") {
    VarSetCapacity(Var, StrPut(Uri, "UTF-8") + 1, 0)
    StrPut(Uri, &Var, "UTF-8")
    NumPut(0, &Var + StrPut(Uri, "UTF-8") - 1, "UChar")
    While Code := NumGet(Var, A_Index - 1, "UChar")
        Res .= (Chr := Chr(Code)) ~= RE ? Chr : Format("%%%02X", Code)
    Return Res
}

LogDebug(msg) {
    if (_debug != false) {
        FormatTime, now,, yyyy-MM-dd HH:mm:ss
        logMsg := "[" . now . "] " . msg . "`n"
        FileAppend, %logMsg%, ./debug.log
    }
}
