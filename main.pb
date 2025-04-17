XIncludeFile "window.pbf" ; Include the first window definition

Global WindowTitle$ = "Shell Manager"

If OpenMutex_(#SYNCHRONIZE, #False, WindowTitle$) = 0
  CreateMutex_(0, #False, WindowTitle$)
Else
  hwnd = FindWindow_(0, WindowTitle$) ; 替换为程序窗口的标题
  If hwnd
    ShowWindow_(hwnd, #SW_RESTORE)         ; 恢复窗口
    SetForegroundWindow_(hwnd)             ; 将窗口置于前台
  EndIf
  End
EndIf

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

Procedure RunItem(index.l)
  If OpenConsole()
    SelectElement(DataList(), index)
    RunProgram(DataList()\cmd)
    CloseConsole()
  EndIf
EndProcedure

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

OpenMainWindow()

LoadConfig()

Repeat
  Event = WaitWindowEvent()
  
  Select EventWindow()
    Case MainWindow
      MainWindow_Events(Event)
      
  EndSelect
  
Until Event = #PB_Event_CloseWindow
; IDE Options = PureBasic 6.20 (Windows - x64)
; CursorPosition = 213
; FirstLine = 169
; Folding = ---
; EnableXP
; DPIAware