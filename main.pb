XIncludeFile "window.pbf" ; Include the first window definition

Global WindowTitle$ = "Shell Manager"

;是否是windows
#IS_WINDOWS_OS = 1

;--------------overlay open----------------

#MutexName = "shell_manager"

Procedure.i IsAlreadyRunning()
  Protected result.i = #False
  Protected mutex.i
  
  Select #PB_Compiler_OS
    Case #PB_OS_Windows
      mutex = CreateMutex_(0, #True, #MutexName)
      If GetLastError_() = #ERROR_ALREADY_EXISTS
        result = #True
      EndIf
    Case #PB_OS_MacOS, #PB_OS_Linux
      ; 使用文件锁定机制
      Protected lockFile.s = "/tmp/" + #MutexName + ".lock"
      mutex = OpenFile(0, lockFile)
      If mutex = 0
        mutex = CreateFile(0, lockFile)
        If mutex = 0
          result = #True
        EndIf
      Else
        result = #True
      EndIf
  EndSelect
  
  ProcedureReturn result
EndProcedure

Procedure BringWindowToFront()
  Select #PB_Compiler_OS
    Case #PB_OS_Windows
      Protected hWnd.i = FindWindow_(0, WindowTitle$)
      If hWnd
        ShowWindow_(hWnd, #SW_RESTORE)
        SetForegroundWindow_(hWnd)
      EndIf
    Case #PB_OS_MacOS
      ; macOS 使用 AppleScript 将窗口置于前台
      RunProgram("/usr/bin/osascript", "-e " + WindowTitle$, "")
    Case #PB_OS_Linux
      ; Linux 使用 `wmctrl` 工具
      RunProgram("wmctrl", "-a " + WindowTitle$, "")
  EndSelect
EndProcedure

If IsAlreadyRunning()
  BringWindowToFront()
  End
EndIf

;-------------------CRUD-----------------------

;列表数据结构
Structure ItemType
  name.s
  cmd.s
EndStructure

;json操作号
#JSON_Data = 0
;cfg操作号
#Config_File = 0

;配置文件目录
Global CfgPath$ = GetTemporaryDirectory() + "cmd_mgr_info.cfg"

;列表数据
Global NewList DataList.ItemType()

;json对象
Global JsonRoot, JsonList, JsonIndex
Global LastIndex.l = -1, LastTime.q

Procedure.s GetShowName(name$, cmd$)
  ProcedureReturn "[" + name$ + "] -> " + cmd$
EndProcedure

Procedure SelectItem(index.l)
  SetJSONInteger(JsonIndex, index)
  If index >= 0 And index <= CountGadgetItems(ListCmd) - 1
    SetGadgetState(ListCmd, index)
    SelectElement(DataList(), index)
    SetGadgetText(TxtName, DataList()\name)
    SetGadgetText(TxtCommand, DataList()\cmd)
  EndIf
EndProcedure

;加载配置
Procedure LoadConfig()
  If ReadFile(#Config_File, CfgPath$)
    First$ =  Trim(ReadString(#Config_File))
    If ParseJSON(#JSON_Data, First$)
      JsonRoot = JSONValue(#JSON_Data)
      JsonList = GetJSONMember(JsonRoot, "list")
      JsonIndex = GetJSONMember(JsonRoot, "index")
      ExtractJSONList(JsonList, DataList())
    EndIf
    CloseFile(#Config_File)
  Else
    If CreateJSON(#JSON_Data)
      AddElement(DataList())
      DataList()\name = "test"
      DataList()\cmd = "echo test"
      JsonRoot = SetJSONObject(JSONValue(#JSON_Data))
      JsonList = AddJSONMember(JsonRoot, "list")
      InsertJSONList(JsonList, DataList())
      JsonIndex = AddJSONMember(JsonRoot, "index")
      SetJSONInteger(JsonIndex, 0)
    EndIf
  EndIf
  ;刷新
  ClearGadgetItems(ListCmd)
  ForEach DataList()
    AddGadgetItem(ListCmd, -1, GetShowName(DataList()\name, DataList()\cmd))
  Next
  ;选择
  SelectItem(GetJSONInteger(JsonIndex))
EndProcedure

;json写入配置
Procedure SaveConfig()
  If CreateFile(#Config_File, CfgPath$)
    WriteString(#Config_File, ComposeJSON(#JSON_Data))
    CloseFile(#Config_File)
  EndIf
EndProcedure

;取当前选择的
Procedure.l GetSelectItem()
  CurItem = GetGadgetState(ListCmd)
  If GetGadgetItemState(ListCmd, CurItem)  = #PB_ListIcon_Selected
    ProcedureReturn CurItem
  EndIf
  ProcedureReturn -1
EndProcedure

;添加一个
Procedure AddItem()
  name$ = GetGadgetText(TxtName)
  cmd$ = GetGadgetText(TxtCommand)
  
  LastElement(DataList())
  AddElement(DataList())
  DataList()\name = name$
  DataList()\cmd = cmd$
  
  AddGadgetItem(ListCmd, -1, GetShowName(name$, cmd$))
  
  InsertJSONList(JsonList, DataList())
  
  SelectItem(ListIndex(DataList()))
  
  SaveConfig()
EndProcedure

Procedure EditorItem()
  CurItem = GetSelectItem()
  If CurItem < 0
    MessageRequester(WindowTitle$, "No Selected ", 0)
  Else
    name$ = GetGadgetText(TxtName)
    cmd$ = GetGadgetText(TxtCommand)
    
    SelectElement(DataList(), CurItem) 
    DataList()\name = name$
    DataList()\cmd = cmd$
    
    SetGadgetItemText(ListCmd, CurItem, GetShowName(name$, cmd$))
    
    ele = GetJSONElement(JsonList, CurItem)
    SetJSONString(GetJSONMember(ele, "name"), name$)
    SetJSONString(GetJSONMember(ele, "cmd"), cmd$)
    
    SelectItem(CurItem)
    
    SaveConfig()
  EndIf
EndProcedure

Procedure SwapItem(first, second)
  SelectElement(DataList(), first)
  *FirstElement = @DataList()
  SelectElement(DataList(), second)
  *SecondElement = @DataList()
  SwapElements(DataList(), *FirstElement, *SecondElement)
  
  ele = GetJSONElement(JsonList, first)
  SelectElement(DataList(), first)
  SetJSONString(GetJSONMember(ele, "name"), DataList()\name)
  SetJSONString(GetJSONMember(ele, "cmd"), DataList()\cmd)
  SetGadgetItemText(ListCmd, first, GetShowName(DataList()\name, DataList()\cmd))
  ele = GetJSONElement(JsonList, second)
  SelectElement(DataList(), second)
  SetJSONString(GetJSONMember(ele, "name"), DataList()\name)
  SetJSONString(GetJSONMember(ele, "cmd"), DataList()\cmd)
  SetGadgetItemText(ListCmd, second, GetShowName(DataList()\name, DataList()\cmd))
  
  SelectItem(second)
  
  SaveConfig()
EndProcedure

Procedure RemoveItem()
  CurItem = GetSelectItem()
  If CurItem < 0 
    MessageRequester(WindowTitle$, "No Selected ", 0)
  Else
    DeleteElement(DataList(), CurItem)
    
    RemoveGadgetItem(ListCmd, CurItem)
    
    RemoveJSONElement(JsonList, CurItem)
    
    If CurItem - 1 < 0 And CountGadgetItems(ListCmd) > 0
      SelectItem(0)
    Else
      SelectItem(CurItem - 1)
    EndIf
    
    SaveConfig()
  EndIf
EndProcedure

Procedure RunShell(command$)
  tempPath$ = GetTemporaryDirectory()
  Select #PB_Compiler_OS
    Case #PB_OS_Windows
      scriptFile$ = tempPath$ + "run_command.bat"
      runCommand$ = scriptFile$
    Case #PB_OS_MacOS, #PB_OS_Linux
      scriptFile$ = tempPath$ + "run_command.sh"
      runCommand$ = "sh " + scriptFile$
  EndSelect
  
  If CreateFile(0, scriptFile$)
    WriteStringN(0, command$)
    CloseFile(0)
  Else
    MessageRequester(WindowTitle$, "Couldn't create shell file", 0)
  EndIf
  
  If #PB_Compiler_OS = #PB_OS_MacOS Or #PB_Compiler_OS = #PB_OS_Linux
    RunProgram("chmod", "+x " + scriptFile$, "")
  EndIf
  
  If Not RunProgram(runCommand$)
    MessageRequester(WindowTitle$, "Couldn't run shell file", 0)
  EndIf
EndProcedure

Procedure RunItem(index.l)
  SelectElement(DataList(), index)
  RunShell(DataList()\cmd)
EndProcedure

;---------------wdinwos event-------------------

Procedure BtnRunEvent(EventType)
  CurItem = GetSelectItem()
  If CurItem >= 0 
    RunItem(CurItem)
  EndIf
EndProcedure

Procedure BtnAddEvent(EventType)
  AddItem()
EndProcedure

Procedure BtnDelEvent(EventType)
  RemoveItem()
EndProcedure

Procedure BtnSaveEvent(EventType)
  EditorItem()
EndProcedure

Procedure BtnUpEvent(EventType)
  CurItem = GetSelectItem()
  If CurItem < 0
    MessageRequester(WindowTitle$, "No Selected ", 0)
  Else
    If CurItem <=0
      MessageRequester(WindowTitle$, "Is Top", 0)
    Else
      SwapItem(CurItem, CurItem - 1)
    EndIf
  EndIf
EndProcedure

Procedure BtnDownEvent(EventType)
  CurItem = GetSelectItem()
  If CurItem < 0
    MessageRequester(WindowTitle$, "No Selected ", 0)
  Else
    If CurItem >= (ListSize(DataList()) - 1)
      MessageRequester(WindowTitle$, "Is Bottom", 0)
    Else
      SwapItem(CurItem, CurItem + 1)
    EndIf
  EndIf
EndProcedure

Procedure ListCmdEvent(EventType)
  CurItem = GetSelectItem()
  If CurItem >= 0 
    If LastIndex = CurItem And ElapsedMilliseconds() - LastTime < 250
      RunItem(CurItem)
      LastIndex = -1
      ProcedureReturn
    EndIf
    LastIndex = CurItem
    LastTime = ElapsedMilliseconds()
    SelectItem(CurItem)
    SaveConfig()
  EndIf
EndProcedure

;------------------tray----------------

CompilerIf #IS_WINDOWS_OS
  #WM_USER = $0400
  #WM_TRAYICON = #WM_USER + 1
  #NIM_ADD = 0
  #NIM_MODIFY = 1
  #NIM_DELETE = 2
  #NIF_MESSAGE = $1
  #NIF_ICON = $2
  #NIF_TIP = $4
  
  #TRAY_MENU = 0
  #TRAY_MENU_EXIT = 0
  
  Global TrayIcon.NOTIFYICONDATA
  
  Procedure CreateTrayIcon()
    Protected hIcon.i
    ExtractIconEx_(ProgramFilename(), 0, @hIcon, 0, 1)
    TrayIcon\cbSize = SizeOf(NOTIFYICONDATA)
    TrayIcon\hWnd = FindWindow_(0, WindowTitle$)
    TrayIcon\uID = 1
    TrayIcon\uFlags = #NIF_MESSAGE | #NIF_ICON | #NIF_TIP
    TrayIcon\uCallbackMessage = #WM_TRAYICON
    TrayIcon\hIcon = hIcon
    PokeS(@TrayIcon\szTip, WindowTitle$, -1, #PB_Unicode)
    Shell_NotifyIcon_(#NIM_ADD, @TrayIcon)
  EndProcedure
  
  Procedure CreateTrayMenu()
    If CreatePopupMenu(#TRAY_MENU)
      Define index.i = 1
      ForEach DataList()
        MenuItem(index, DataList()\name)  
        index + 1
      Next
      If ListSize(DataList()) > 0
        MenuBar()
      EndIf 
      MenuItem(#TRAY_MENU_EXIT, "Exit")  
    EndIf
  EndProcedure
  
  Procedure RemoveTrayIcon()
    Shell_NotifyIcon_(#NIM_DELETE, @TrayIcon)
  EndProcedure
  
  Procedure DoTrayMenuEvent()
    result.l = EventMenu()
    Select result
      Case #TRAY_MENU_EXIT
        RemoveTrayIcon()
        End
      Default
        RunItem(result-1)
    EndSelect
  EndProcedure
  
  Procedure ShowTrayMenu()
    CreateTrayMenu()
    DisplayPopupMenu(#TRAY_MENU, WindowID(MainWindow))
  EndProcedure
  
  Procedure MainWindowCallback(_windowID, Message, wParam, lParam)
    Select Message
      Case #WM_CLOSE
        HideWindow(MainWindow, #True)
      Case #WM_TRAYICON
        If lParam = #WM_LBUTTONDBLCLK
          HideWindow(MainWindow, #False)
          SetForegroundWindow_(WindowID(MainWindow))
        ElseIf lParam = #WM_RBUTTONDOWN
          ShowTrayMenu()
        EndIf
    EndSelect
    ProcedureReturn #PB_ProcessPureBasicEvents
  EndProcedure
  
CompilerEndIf

;---------------main loop----------------

OpenMainWindow()

CompilerIf #IS_WINDOWS_OS
  CreateTrayMenu()
  CreateTrayIcon()
  SetWindowCallback(@MainWindowCallback())
CompilerEndIf

LoadConfig()

Repeat
  Event = WaitWindowEvent()
  
  If Event = #PB_Event_Menu
    CompilerIf #IS_WINDOWS_OS
      DoTrayMenuEvent()
    CompilerEndIf
  EndIf
  
  Select EventWindow()
    Case MainWindow
      MainWindow_Events(Event)
  EndSelect
  
  CompilerIf #IS_WINDOWS_OS
  ForEver
CompilerElse
Until Event = #PB_Event_CloseWindow
CompilerEndIf

; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 438
; FirstLine = 390
; Folding = ------
; EnableXP
; DPIAware