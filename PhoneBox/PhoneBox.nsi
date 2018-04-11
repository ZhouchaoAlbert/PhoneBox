; 选择压缩方式
SetCompressor /SOLID LZMA

; 引入的头文件
!include "nsDialogs.nsh"
!include "FileFunc.nsh"
!include  MUI.nsh
!include  LogicLib.nsh
!include  WinMessages.nsh
!include "MUI2.nsh"
!include "WordFunc.nsh"
!include "Library.nsh"

; 引入的dll
ReserveFile "${NSISDIR}\Plugins\BgWorker.dll"
ReserveFile "${NSISDIR}\Plugins\DuiLib.dll"
ReserveFile "${NSISDIR}\Plugins\FindProcDLL.dll"
ReserveFile "${NSISDIR}\Plugins\KillProcDLL.dll"
ReserveFile "${NSISDIR}\Plugins\nsDialogs.dll"
ReserveFile "${NSISDIR}\Plugins\nsis7z.dll" 
ReserveFile "${NSISDIR}\Plugins\nsProcessW.dll"
ReserveFile "${NSISDIR}\Plugins\UISkin.dll" ;调用我们的皮肤插件
ReserveFile "${NSISDIR}\Plugins\System.dll"
ReserveFile "${NSISDIR}\Plugins\Nsis7zP.dll"
ReserveFile "${NSISDIR}\Plugins\7z.dll"
ReserveFile "${NSISDIR}\Plugins\NsisPro.dll"


; 名称宏定义
!define PRODUCT_NAME      			"PhoneBox"
!define PRODUCT_VERSION   			"1.0.4.6"
!define PRODUCT_SHORTCUT_NAME       "电话宝"
!define PRODUCT_PATH      			"PhoneBox"
!define MUI_ICON          			"imageres\setup.ico"     ; 安装icon
!define MUI_UNICON        			"imageres\uninstall.ico"  ; 卸载icon

# ===================== 安装包版本 =============================
VIProductVersion             	    "${PRODUCT_VERSION}"
VIAddVersionKey "ProductVersion"    "${PRODUCT_VERSION}"
VIAddVersionKey "ProductName"       "${PRODUCT_NAME}"
VIAddVersionKey "CompanyName"       "深圳市六度人和科技有限公司"
VIAddVersionKey "FileVersion"       "${PRODUCT_VERSION}"
VIAddVersionKey "InternalName"      "PhoneBox.exe"
VIAddVersionKey "FileDescription"   "${PRODUCT_NAME}"
VIAddVersionKey "LegalCopyright"    "版权所有（c）2016 六度人和"

;Languages 
!insertmacro MUI_LANGUAGE "SimpChinese"

Var Dialog
Var MessageBoxHandle

Var FastIconState
Var FreeSpaceSize
Var installPath
Var InstallState
Var UnInstallValue  #卸载的进度  
Var EditPath        ;编辑路径
Var EditName        ;编辑名字
Name      "${PRODUCT_NAME}"  

; 输出的安装包名
OutFile   "PhoneBox_Install_${PRODUCT_VERSION}.exe"  

InstallDir "$PROGRAMFILES\${PRODUCT_NAME}"           ;定义安装目录
InstallDirRegKey HKLM "Software\${PRODUCT_NAME}" ""  ;Get installation folder from registry if  available

RequestExecutionLevel admin   ;Request application privileges for Windows Vista

Section "None"
SectionEnd

; 安装和卸载页面
Page         custom     PhoneBoxPageUI
UninstPage   custom     un.PhoneBoxPageUI


Function .onInit
	#初始化插件目录加载
    InitPluginsDir
	File "/ONAME=$PLUGINSDIR\msvcr120.dll" "Plugins\msvcr120.dll"
	File "/ONAME=$PLUGINSDIR\msvcp120.dll" "Plugins\msvcp120.dll" 
	File "/ONAME=$PLUGINSDIR\UISkin.dll" "Plugins\UISkin.dll" 
	File "/ONAME=$PLUGINSDIR\DuiLib.dll" "Plugins\DuiLib.dll" 
	File "/ONAME=$PLUGINSDIR\BgWorker.dll" "Plugins\BgWorker.dll" 
	File "/ONAME=$PLUGINSDIR\FindProcDLL.dll" "Plugins\FindProcDLL.dll" 
	File "/ONAME=$PLUGINSDIR\KillProcDLL.dll" "Plugins\KillProcDLL.dll" 
	File "/ONAME=$PLUGINSDIR\nsis7z.dll" "Plugins\nsis7z.dll" 
	File "/ONAME=$PLUGINSDIR\nsProcessW.dll" "Plugins\nsProcessW.dll" 
	File "/ONAME=$PLUGINSDIR\System.dll" "Plugins\System.dll" 
	File "/ONAME=$PLUGINSDIR\Nsis7zP.dll" "Plugins\Nsis7zP.dll" 
	File "/ONAME=$PLUGINSDIR\7z.dll" "Plugins\7z.dll" 
	File "/ONAME=$PLUGINSDIR\NsisPro.dll" "Plugins\NsisPro.dll"
	
	#初始化皮肤插件
	SetOutPath "$PLUGINSDIR"
    File /r "imageres\*"
	UISkin::InitSkinEngine "$PLUGINSDIR\"  
	
    #初始化MsgBox窗口
    UISkin::InitMessageBox "MessageBox.xml" "label_box_title" "text_box_tip" "btn_box_close" "btn_box_yes" "btn_box_no" "setup.ico"
    Pop $MessageBoxHandle 
	
	#检测程序是否正在运行
    System::Call 'kernel32::CreateMutexW(i 0, i 0, t "电话宝") i .r1 ?e'
    Pop $R1	 ;安装程序已经运行
    StrCmp $R1 0 AA BB
	BB: 	;弹窗提示
	 UISkin::ShowMessageBox "提示" "电话宝 安装包程序已经在运行！" "确定" "取消"
	 UISkin::ExitSkinEngine
    Abort
AA:

FunctionEnd

Function .onGUIEnd
 
FunctionEnd

Function PhoneBoxPageUI
    ;初始化窗口  
	InitPluginsDir   	
	SetOutPath "$PLUGINSDIR"
	File /r "imageres\*"
    ;安装主界面
	UISkin::ShowInstallSkin "install.xml" "setup.ico" "电话宝"
	Pop $Dialog	  
    ;设置焦点
    UISkin::SetControlFocusEX "btn_main_install" 
	 ;自定义按钮绑定函数
    Call BindUIControls	    

    #标题设置
	UISkin::SetControlData "label_caption" "安装" "text"
	
	StrCpy $EditPath $INSTDIR  ;初始化下路径
	Call GetDefaultPath
    UISkin::SetControlData "edt_define_path" $INSTDIR "text" 
    StrCpy $EditPath $INSTDIR  ;初始化下路径
    Call UpdateFreeSpace
	
	;显示窗口
    UISkin::ShowPage
FunctionEnd

;绑定控件
Function BindUIControls
;mainpage 
	GetFunctionAddress $0 OnMinBtnFunc     ;最小化按钮
	UISkin::OnBindControl "btn_min"  $0
	GetFunctionAddress $0 OnCloseBtnFunc    ;关闭按钮
	UISkin::OnBindControl "btn_close"  $0
	GetFunctionAddress $0 OnInstallBtnFunc    ;绑定主界面安装
	UISkin::OnBindControl "btn_main_install"  $0

	GetFunctionAddress $0 OnEditPathFunc  ;路径    
	UISkin::OnBindControl "edt_define_path"  $0
	
	GetFunctionAddress $0 OnEditPathFunc  ;磁盘空间  
	UISkin::OnBindControl "label_use_space"  $0  
	
	GetFunctionAddress $0 OnOpenBrowserFrameFunc  ;浏览按钮    
	UISkin::OnBindControl "btn_define_browser"  $0
	
	GetFunctionAddress $0 OnLabelCaptionFunc  ;修改标题    
	UISkin::OnBindControl "label_caption"  $0
	
;definepage

	GetFunctionAddress $0 OnGetShortCutStatusFunc  ;快捷键的状态    
	UISkin::OnBindControl "chk_define_shortcut"  $0
	GetFunctionAddress $0 OnGetAutoStartStatusFunc ;开机自启动    
	UISkin::OnBindControl "chk_define_autostart"  $0
  	
;finishpage
	GetFunctionAddress $0 OnExpressBtnFunc  ;立即体验  
	UISkin::OnBindControl "btn_finish_express"  $0
  
	GetFunctionAddress $0 OnFinished  ;完成关闭按钮  
	UISkin::OnBindControl "btn_finish_close"  $0
FunctionEnd


;installpage页
Function OnInstallBtnFunc
   
   ;先判断安装路径是否正确
   UISkin::GetDiskSpaceFreeSizeEX "$EditPath"
   Pop $R1
   ${if} $R1 == 1 ;成功
    UISkin::CreateDirectoryPath "$EditPath"
    Pop $R0
    ${if} $R0 == 1 ;成功
        StrCpy $INSTDIR  $EditPath
    ${else}
      UISkin::ShowMessageBox "提示" "安装路径有特殊字符,请重新输入" "确定" "取消"
      goto MMM
    ${endif}
	${else} ;路径不存在
    UISkin::ShowMessageBox "提示" "安装目录不存在,请重新设置" "确定" "取消"
    goto MMM
	${endif}
    
	UISkin::GetInstallFileName "$EditPath"
	Pop $EditName
	${if} $EditName == "" ;失败 
		 UISkin::ShowMessageBox "提示" "安装路径有误,请输入安装目录名字" "确定" "取消"
		 goto MMM
	${endif}  
	
   ;安装前更新下磁盘
    Call UpdateFreeSpace
	;判断空间大小
    ${If} $FreeSpaceSize < 140                             
        UISkin::ShowMessageBox "提示" "空间不足,请选择其它分区安装!"  "确定" "取消"
        Abort  
    ${endif} 
    
    #此处检测当前是否有程序正在运行，如果正在运行， 
    nsProcessW::_FindProcess "PhoneBox.exe"
    Pop $R0	
    ${If} $R0 == 0
        UISkin::ShowMessageBox "提示" "您的 电话宝 正在运行,是否关闭开始安装?" "开始安装" "取消"
        Pop $R1 
        ${If} $R1 == 1
          Call KillAllProc
        ${EndIf}
        ${If} $R1 == 2
         goto  MMM
        ${EndIf}
    ${else}
      Call KillAllProc
    ${EndIf}		

    #写入注册信息 
    SetRegView 32
    WriteRegStr HKLM "Software\${PRODUCT_NAME}" "" $INSTDIR

    UISkin::ShowPageItem  "WizardTab" "1"

    #启动一个低优先级的后台线程
    GetFunctionAddress $0 ExtractFunc
    BgWorker::CallAndWait

    Call BuildShortCut

MMM:
FunctionEnd

;finishpage页
Function OnFinishBtnFunc
   UISkin::ShowPageItem  "WizardTab" "2"
   UISkin::SetControlFocusEX "btn_finish_express"
FunctionEnd

Function OnFinished
      UISkin::ExitSkinEngine
FunctionEnd

Function ExtractFunc

	#安装文件的7Z压缩包  
    SetOutPath $INSTDIR
    File "Release.7z"
    GetFunctionAddress $R9 ExtractCallback
    ;nsis7z::ExtractWithCallback  "$INSTDIR\Release.7z" $R9
	Nsis7zP::Extract7zAndCallBack "$INSTDIR\Release.7z" $R9
    Delete "$INSTDIR\Release.7z"
    Sleep 50
FunctionEnd

Function ExtractCallback
    Pop $1
    Pop $2
	${If} $1 == -1	
	  ${If} $2 == -9
	      Pop $3 ;被占用的文件
		  UISkin::ShowMessageBox "提示" "安装失败！文件（$3）被占用， 请选择 “重试”再次安装。"  "重试" "退出"
		  Pop $R1 
		  ${If} $R1 == 1
			Call KillAllProc ;重新解压时把所有进程关闭
		  ${else}
			UISkin::ExitSkinEngine
		  ${EndIf}
	  ${ElseIf} $2 == -6  ; NSISP 会返回-6 这是 重新解压7z安装包
		  GetFunctionAddress $R9 ExtractCallback
		  Nsis7zP::Extract7zAndCallBack "$INSTDIR\Release.7z" $R9
		  Delete "$INSTDIR\Release.7z"
		  Sleep 50
	  ${else} ;其他解压失败处理
		UISkin::ShowMessageBox "提示" "安装包解压失败，请退出重新安装($2)。"  "确定" "取消"
		Pop $R2 
		${If} $R2 == 1
			UISkin::ExitSkinEngine
		${EndIf}
	  ${EndIf}
	${else}
		System::Int64Op $1 * 100 
		Pop $3
		System::Int64Op $3 / $2
		Pop $0
		System::Int64Op $0 * 90
		Pop $4
		System::Int64Op $4 / 100
		Pop $5
		UISkin::SetProgressValue "install_define_progress" $5
		UISkin::SetPercentValue "intall_percent" $5
		
		${If} $1 == $2
			UISkin::SetProgressValue "install_define_progress" 100   
			UISkin::SetPercentValue "intall_percent" 100	     
			Call OnFinishBtnFunc
		${EndIf} 
	 ${endif}
FunctionEnd


;获取快捷键状态
Function OnGetShortCutStatusFunc

FunctionEnd

;获取自启动状态
Function OnGetAutoStartStatusFunc
FunctionEnd

;打开浏览框
Function OnOpenBrowserFrameFunc
    nsDialogs::SelectFolderDialog  "请选择 ${PRODUCT_NAME} 安装目录："  "$0"
    Pop $0
    ${IfNot} $0 == error
        System::Call `shlwapi::PathCombine(t.r0,tr0,t"${PRODUCT_NAME}")`
        StrCpy $INSTDIR $0
        UISkin::SetControlData "edt_define_path" $INSTDIR "text"     
        StrCpy $EditPath $INSTDIR  ;初始化下路径
        Call UpdateFreeSpace
    ${EndIf} 
FunctionEnd

Function OnLabelCaptionFunc
FunctionEnd

;路径编辑框 可以判断路径是否合法
Function OnEditPathFunc   
	UISkin::GetControlData "edt_define_path"  "text" 
	Pop $EditPath
FunctionEnd

;立即体验
Function OnExpressBtnFunc 
    ExecShell "" "$INSTDIR\PhoneBox.exe"
    ;退出皮肤进程
    UISkin::ExitSkinEngine 
FunctionEnd


;获取磁盘空间及更新
Function UpdateFreeSpace
  ${GetRoot} $INSTDIR $0
  StrCpy $1 "Bytes"
  System::Call kernel32::GetDiskFreeSpaceEx(tr0,*l,*l,*l.r0)
   ${If} $0 > 1024
   ${OrIf} $0 < 0
      System::Int64Op $0 / 1024
      Pop $0
      StrCpy $1 "KB"
      ${If} $0 > 1024
      ${OrIf} $0 < 0
	 System::Int64Op $0 / 1024
	 Pop $0
	 StrCpy $FreeSpaceSize $0
	 StrCpy $1 "MB"
	 ${If} $0 > 1024
	 ${OrIf} $0 < 0
	    System::Int64Op $0 / 1024
	    Pop $0
	    StrCpy $1 "GB"
	 ${EndIf}
      ${EndIf}
   ${EndIf}

   ;更新磁盘空间文本显示
   UISkin::SetControlData "label_use_space" "$0$1"  "text"
FunctionEnd

;最小话按钮
Function OnMinBtnFunc
	ShowWindow $Dialog 6
FunctionEnd

;////////////////////////MessageBox////////////////////////////
Function OnCloseBtnFunc
	UISkin::ShowMessageBox "提示" "您确定要退出 电话宝 安装程序吗?" "确定" "取消"
	Pop $R1 
    ${If} $R1 == 1
      UISkin::ExitSkinEngine
    ${EndIf}
FunctionEnd
;////////////////////////////////////////////////////////

Function BuildShortCut 
   	SetRegView 32
	DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
	DeleteRegKey HKLM "Software\${PRODUCT_NAME}"	
	SetShellVarContext all  ; 删除快捷方式
	Delete "$SMPROGRAMS\${PRODUCT_SHORTCUT_NAME}\${PRODUCT_SHORTCUT_NAME}.lnk"
	Delete "$SMPROGRAMS\${PRODUCT_SHORTCUT_NAME}\卸载${PRODUCT_SHORTCUT_NAME}.lnk"
	RMDir  "$SMPROGRAMS\${PRODUCT_SHORTCUT_NAME}"
	Delete "$DESKTOP\${PRODUCT_SHORTCUT_NAME}.lnk"
	#删除开机启动  
	Delete "$SMSTARTUP\${PRODUCT_SHORTCUT_NAME}.lnk"
	SetShellVarContext current
	Delete "$DESKTOP\${PRODUCT_SHORTCUT_NAME}.lnk"
	RMDir /r "$SMPROGRAMS\${PRODUCT_SHORTCUT_NAME}"
   
   

   ;EC10 体验版   ;开始菜单
   SetShellVarContext all
   CreateDirectory "$SMPROGRAMS\${PRODUCT_SHORTCUT_NAME}"
   CreateShortCut "$SMPROGRAMS\${PRODUCT_SHORTCUT_NAME}\${PRODUCT_SHORTCUT_NAME}.lnk" "$INSTDIR\PhoneBox.exe" ""
   CreateShortCut "$SMPROGRAMS\${PRODUCT_SHORTCUT_NAME}\卸载${PRODUCT_SHORTCUT_NAME}.lnk" "$INSTDIR\Uninst.exe" 
  
  
  

   ;桌面快捷方式	
   SetShellVarContext all
   CreateShortCut "$DESKTOP\${PRODUCT_SHORTCUT_NAME}.lnk" "$INSTDIR\PhoneBox.exe" ""   
   SetShellVarContext current
		

  ;版本号
!ifdef VER_MAJOR & VER_MINOR & VER_REVISION & VER_BUILD
  WriteRegDword HKLM "Software\${PRODUCT_NAME}" "VersionMajor" "${VER_MAJOR}"
  WriteRegDword HKLM "Software\${PRODUCT_NAME}" "VersionMinor" "${VER_MINOR}"
  WriteRegDword HKLM "Software\${PRODUCT_NAME}" "VersionRevision" "${VER_REVISION}"
  WriteRegDword HKLM "Software\${PRODUCT_NAME}" "VersionBuild" "${VER_BUILD}"
!endif
  ;注册表
  ;控制面板卸载连接
  WriteUninstaller $INSTDIR\Uninst.exe
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "DisplayName" "${PRODUCT_NAME}"
  WriteRegExpandStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "UninstallString" '"$INSTDIR\Uninst.exe"'
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "DisplayIcon" "$INSTDIR\PhoneBox.exe"
  WriteRegExpandStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "DisplayVersion" "${VERSION}"
  
!ifdef VER_MAJOR & VER_MINOR & VER_REVISION & VER_BUILD
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "VersionMajor" "${VER_MAJOR}"
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "VersionMinor" "${VER_MINOR}.${VER_REVISION}"
!endif
  ;WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "URLInfoAbout" "http://www.workec.com/"
  ;WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "HelpLink" "http://www.workec.com/"
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "NoModify" "1"
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "NoRepair" "1"

  
   SetShellVarContext all
	 DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "MiaLive"
   SetShellVarContext current
  
FunctionEnd


#获取安装包默认路径
Function GetDefaultPath
    #读注册表上次安装包的路径
	SetRegView 32
    ReadRegStr $0 HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}" "InstallLocation"
	${If} "$0" != ""		#路径不存在，则重新选择路径  	
		#路径读取到了，直接使用 
		Pop $0
		StrCpy $INSTDIR "$0"
	${EndIf}
FunctionEnd


;//////////////////////////////////////////////以下是卸载操作//////////////////////////////////////////////////
Function un.onInit	  
	InitPluginsDir
	File "/ONAME=$PLUGINSDIR\msvcr120.dll" "Plugins\msvcr120.dll"
	File "/ONAME=$PLUGINSDIR\msvcp120.dll" "Plugins\msvcp120.dll" 
	File "/ONAME=$PLUGINSDIR\UISkin.dll" "Plugins\UISkin.dll" 
	File "/ONAME=$PLUGINSDIR\DuiLib.dll" "Plugins\DuiLib.dll" 
	File "/ONAME=$PLUGINSDIR\BgWorker.dll" "Plugins\BgWorker.dll" 
	File "/ONAME=$PLUGINSDIR\FindProcDLL.dll" "Plugins\FindProcDLL.dll" 
	File "/ONAME=$PLUGINSDIR\KillProcDLL.dll" "Plugins\KillProcDLL.dll" 
	File "/ONAME=$PLUGINSDIR\nsis7z.dll" "Plugins\nsis7z.dll" 
	File "/ONAME=$PLUGINSDIR\nsProcessW.dll" "Plugins\nsProcessW.dll" 
	File "/ONAME=$PLUGINSDIR\System.dll" "Plugins\System.dll" 
	File "/ONAME=$PLUGINSDIR\Nsis7zP.dll" "Plugins\Nsis7zP.dll" 
	File "/ONAME=$PLUGINSDIR\7z.dll" "Plugins\7z.dll" 
	File "/ONAME=$PLUGINSDIR\NsisPro.dll" "Plugins\NsisPro.dll"
	
	SetOutPath "$PLUGINSDIR"
    File /r "imageres\*"
	UISkin::InitSkinEngine "$PLUGINSDIR\"  
	
   ;初始化MsgBox窗口
    UISkin::InitMessageBox "MessageBox.xml" "label_box_title" "text_box_tip" "btn_box_close" "btn_box_yes" "btn_box_no" "setup.ico"
    Pop $MessageBoxHandle 
	
    System::Call 'kernel32::CreateMutexW(i 0, i 0, t "电话宝") i .r1 ?e'
    Pop $R1	 ;安装程序已经运行
    StrCmp $R1 0 AA BB
	BB: ;弹窗提示
	 UISkin::ShowMessageBox "提示" "电话宝 卸载包程序已经在运行！" "确定" "取消"
	 UISkin::ExitSkinEngine
    Abort
AA:

FunctionEnd

Function un.PhoneBoxPageUI

   ;初始化窗口  
	InitPluginsDir   	
	SetOutPath "$PLUGINSDIR"
    File /r "imageres\*"
	
    ;卸载主界面
	UISkin::ShowInstallSkin "install.xml" "setup.ico" "电话宝"
	Pop $Dialog	  
	
	UISkin::ShowPageItem  "WizardTab" "3" ;显示卸载主页
    ;绑定函数
	Call un.BindUIControls 
	
	#标题设置
	UISkin::SetControlData "label_caption" "卸载" "text"
	;显示窗口
    UISkin::ShowPage
FunctionEnd


Function un.BindUIControls 
;卸载主页
	GetFunctionAddress $0 un.onUninstall         ;绑定卸载确定按钮
	UISkin::OnBindControl "btn_unmain_sure" $0
	
	#取消卸载
	GetFunctionAddress $0 un.onUninstallFinished 
	UISkin::OnBindControl "btn_unmain_cancel" $0
	
	
	GetFunctionAddress $0 un.onUninstallFinished    
	UISkin::OnBindControl "btn_close" $0
	
	GetFunctionAddress $0 un.OnMinBtnFunc   
	UISkin::OnBindControl "btn_min" $0
	
	GetFunctionAddress $0 un.onUninstallFinished    ;完成确定按钮
	UISkin::OnBindControl "btn_unfinish_sure" $0
	
FunctionEnd

Function un.onUninstallFinished
      UISkin::ExitSkinEngine
FunctionEnd

;最小话按钮
Function un.OnMinBtnFunc
	ShowWindow $Dialog 6
FunctionEnd

Function un.onUninstall 

   ;到卸载页 判断EC是否在运行
	nsProcessW::_FindProcess "PhoneBox.exe"
	Pop $R0
  ${If} $R0 == 0
      UISkin::ShowMessageBox "提示" "您的 电话宝 正在运行,是否关闭立即卸载?" "立即卸载" "以后再说"
      Pop  $R1
      ${If} $R1 == 1  ;立即卸载
           Call un.KillAllProc  
      ${Else} ;关闭
          Call un.onUninstallFinished
          goto NNN
      ${EndIf}
  ${EndIf}
  
	Call un.KillAllProc  

	UISkin::ShowPageItem  "WizardTab" "4"
 
	
	IntOp $UnInstallValue 0 + 1

	IntOp $UnInstallValue $UnInstallValue + 8
	
	#删除文件 
	GetFunctionAddress $0 un.RemoveFiles
	BgWorker::CallAndWait

	SetRegView 32
	DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
	DeleteRegKey HKLM "Software\${PRODUCT_NAME}"	
   ; 删除快捷方式
	SetShellVarContext all
	Delete "$SMPROGRAMS\${PRODUCT_SHORTCUT_NAME}\${PRODUCT_SHORTCUT_NAME}.lnk"
	Delete "$SMPROGRAMS\${PRODUCT_SHORTCUT_NAME}\卸载${PRODUCT_SHORTCUT_NAME}.lnk"
	RMDir /r $INSTDIR
	RMDir  "$SMPROGRAMS\${PRODUCT_SHORTCUT_NAME}"
	Delete "$DESKTOP\${PRODUCT_SHORTCUT_NAME}.lnk"
	#删除开机启动  
	Delete "$SMSTARTUP\${PRODUCT_SHORTCUT_NAME}.lnk"
	SetShellVarContext current
	Delete "$DESKTOP\${PRODUCT_SHORTCUT_NAME}.lnk"
	RMDir /r "$SMPROGRAMS\${PRODUCT_SHORTCUT_NAME}"
NNN:
FunctionEnd


#在线程中删除文件，以便显示进度 
Function un.RemoveFiles
	${Locate} "$INSTDIR" "/G=0 /M=*.*" "un.onDeleteFileFound"
	StrCpy $InstallState "1"
	UISkin::SetProgressValue "progress_uinstall" 100
	UISkin::SetPercentValue  "unintall_percent" 100
	UISkin::ShowPageItem "WizardTab" "5"   ;显示完成页面
FunctionEnd


#卸载程序时删除文件的流程，如果有需要过滤的文件，在此函数中添加  
Function un.onDeleteFileFound
    ; $R9    "path\name"
    ; $R8    "path"
    ; $R7    "name"
    ; $R6    "size"  ($R6 = "" if directory, $R6 = "0" if file with /S=)
    
	
	#是否过滤删除  
			
	Delete "$R9"
	RMDir /r "$R9"
    RMDir "$R9"
	
	IntOp $UnInstallValue $UnInstallValue + 2
	${If} $UnInstallValue > 100
		IntOp $UnInstallValue 100 + 0
		UISkin::SetProgressValue "progress_uinstall" 100
	${Else}
		UISkin::SetProgressValue "progress_uinstall" $UnInstallValue
		UISkin::SetPercentValue  "unintall_percent" $UnInstallValue
		Sleep 100
	${EndIf}	
	undelete:
	Push "LocateNext"	
FunctionEnd


;杀死所有进程
Function KillAllProc
	NsisPro::InitNsisPlugins
AA:
    NsisPro::KillProcess "PhoneBox.exe"
    Sleep 100
    NsisPro::FindProcess "PhoneBox.exe"
    Pop $R0	
    StrCmp $R0 "1" BB CC
    BB:
      UISkin::ShowMessageBox "提示" "电话宝 进程正在运行,请手动关闭后点击“重试”" "重试" "取消"
      Pop  $R1
      ${If} $R1 == 1  ; 重试
       Sleep 300
        goto AA
      ${else} ;关闭
        Call OnFinished
      ${EndIf}
CC:
FunctionEnd

Function un.KillAllProc
	NsisPro::InitNsisPlugins
AA:
    NsisPro::KillProcess "PhoneBox.exe"
    Sleep 100
    NsisPro::FindProcess "PhoneBox.exe"
    Pop $R0	
    StrCmp $R0 "1" BB CC
    BB:
      UISkin::ShowMessageBox "提示" "电话宝 进程正在运行,请手动关闭后点击“重试”" "重试" "取消"
      Pop  $R1
      ${If} $R1 == 1  ; 重试
        Sleep 300
        goto AA
      ${else} ;关闭
        Call un.onUninstallFinished
      ${EndIf}
CC:
FunctionEnd