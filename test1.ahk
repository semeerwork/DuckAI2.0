; ===============================
; AutoHotkey v1 — DuckGPT Assistant for Chat Agents (self-contained)
; ===============================

Global API_Endpoint := "https://duckgpt.live/chat/?prompt="
Global PromptPresets := {
    "Rephrase": "Rephrase the following text or paragraph to ensure clarity, conciseness, and a natural flow. The revision should preserve the tone, style, and formatting of the original. Respond without comments or elaboration",
    "Agent": "I work as technical chat support agent for web hosting company. help me with refining my responses. Please refine the following text according to these guidelines:- **Tone & Clarity:** Use simple, empathetic. Avoid jargon. Use a customer service tone. Do not use 'Unfortunately.' Ensure responses are supportive and engaging, making it easy for customers to understand.- The revision should preserve the tone, style, and formatting of the original. **Currency & Dates:** Use '$' for currency. Format dates as MMM DD, YYYY (e.g., Oct 29, 2010). **Links:** Provide links explicitly. Don't include 'Thank you' at the end. Respond without comments or elaboration. Text to rephrase:",
    "Answer": "Answer the following question concisely in plain text without markdown:",
    "Expand": "Expand the following text, The revision should preserve the tone, style, and formatting of the original, Respond without comments:",
    "Give in steps": "Provide following text in steps in plain text without markdown:",
    "Summarize": "Summarize the following text concisely:"
}

; === Hotkeys ===
F5::ShowPromptMenu()
^'::SendProcessedPrompt("Agent")

; === Menu Rendering ===
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

; === Core Prompt Execution ===
SendProcessedPrompt(PresetLabel) {
    Try {
        PromptTemplate := PromptPresets[PresetLabel]
        If (!PromptTemplate) {
            MsgBox, 48, Prompt Error, Invalid prompt preset: %PresetLabel%
            Return
        }

        clipboardBackup := ClipboardAll
        Send, ^c
        ClipWait, 1
        userInput := Clipboard
        Clipboard := clipboardBackup

        If (!Trim(userInput)) {
            MsgBox, 48, Clipboard Empty, Please select and copy some text first.
            Return
        }

        finalPrompt := PromptTemplate . " " . userInput
        aiResponse := FetchDuckGPT(finalPrompt)

        If (!aiResponse) {
            MsgBox, 16, API Error, Failed to retrieve a valid response from the AI.
            Return
        }

        clean := CleanAIResponse(aiResponse)
        SendInput, %clean%
    } Catch e {
        MsgBox, 16, Unexpected Error, % "Something went wrong:`n" . e.Message
    }
}

; === API Communication ===
FetchDuckGPT(prompt) {
    encodedPrompt := UriEncode(prompt)
    url := API_Endpoint . encodedPrompt

    http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    Loop, 2
    {
        Try {
            http.Open("GET", url, false)
            http.SetTimeouts(3000, 3000, 3000, 3000)
            http.Send()

            If (http.Status = 200) {
                responseText := http.ResponseText
                json := JSON_Load(responseText)
                If (json && json.response)
                    Return json.response
            }
        } Catch e {
            Sleep, 300
            Continue
        }
    }
    Return ""
}

; === Response Cleanup ===
CleanAIResponse(text) {
    clean := StrReplace(text, "\\n", "`n")
    clean := StrReplace(clean, "\\\"", '"')
    clean := RegExReplace(clean, "\\u[0-9a-fA-F]{4}", "?")
    Return clean
}

; === URI Encode Function ===
UriEncode(Uri, RE := "[0-9A-Za-z]") {
    VarSetCapacity(Var, StrPut(Uri, "UTF-8"), 0)
    StrPut(Uri, &Var, "UTF-8")
    While Code := NumGet(Var, A_Index - 1, "UChar")
        Res .= (Chr := Chr(Code)) ~= RE ? Chr : Format("%%%02X", Code)
    Return Res
}

; === Minimal JSON Load ===
JSON_Load(ByRef text) {
    global __json_text := text, __json_pos := 0
    return __JSON_Parse()
}

__JSON_Parse() {
    global __json_text, __json_pos
    static quot := Chr(34)

    while (ch := SubStr(__json_text, ++__json_pos, 1)) {
        if (InStr(" `t`r`n", ch))
            continue
        if (ch == "{") {
            obj := {}
            loop {
                ch := SubStr(__json_text, ++__json_pos, 1)
                if (InStr(" `t`r`n", ch))
                    continue
                if (ch == "}")
                    break
                if (ch != quot)
                    return ""
                key := __JSON_ParseString()
                ch := SubStr(__json_text, ++__json_pos, 1)
                if (ch != ":")
                    return ""
                val := __JSON_Parse()
                obj[key] := val
                ch := SubStr(__json_text, ++__json_pos, 1)
                if (ch == "}")
                    break
                if (ch != ",")
                    return ""
            }
            return obj
        } else if (ch == quot) {
            return __JSON_ParseString()
        } else if (RegExMatch(SubStr(__json_text, __json_pos), "^-?\d+(\.\d+)?", m)) {
            __json_pos += StrLen(m) - 1
            return m
        } else if (SubStr(__json_text, __json_pos, 4) = "true") {
            __json_pos += 3
            return true
        } else if (SubStr(__json_text, __json_pos, 5) = "false") {
            __json_pos += 4
            return false
        } else if (SubStr(__json_text, __json_pos, 4) = "null") {
            __json_pos += 3
            return ""
        } else return ""
    }
    return ""
}

__JSON_ParseString() {
    global __json_text, __json_pos
    static quot := Chr(34)

    start := ++__json_pos
    while (i := InStr(__json_text, quot, false, __json_pos)) {
        if (SubStr(__json_text, i-1, 1) != "\\") {
            str := SubStr(__json_text, start, i-start)
            __json_pos := i
            return StrReplace(str, "\\\"", "\"")
        }
        __json_pos := i + 1
    }
    return ""
}

