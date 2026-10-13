param([ValidateSet('720p','Restore')][string]$Mode)
$ErrorActionPreference='Stop'
if (-not ('GameDisplay' -as [type])) { Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class GameDisplay {
 [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
 public struct Mode {
  [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)] public string device;
  public ushort spec,driver,size,extra;
  public uint fields;
  public int x,y;
  public uint orientation,fixedOutput;
  public short color,duplex,yResolution,ttOption,collate;
  [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)] public string form;
  public ushort logPixels;
  public uint bits,width,height,flags,frequency,icmMethod,icmIntent,media,dither,reserved1,reserved2,panningWidth,panningHeight;
 }
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]
 public static extern bool EnumDisplaySettings(string name,int index,ref Mode mode);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]
 public static extern int ChangeDisplaySettingsEx(string name,ref Mode mode,IntPtr hwnd,uint flags,IntPtr data);
 public static Mode Read(int index) {var m=new Mode();m.size=(ushort)Marshal.SizeOf(typeof(Mode));if(!EnumDisplaySettings(null,index,ref m))throw new Exception("Cannot read display mode");return m;}
 public static Mode Find(uint width,uint height,uint frequency) {for(int i=0;i<1000;i++){var m=new Mode();m.size=(ushort)Marshal.SizeOf(typeof(Mode));if(!EnumDisplaySettings(null,i,ref m))break;if(m.width==width&&m.height==height&&m.frequency==frequency&&m.bits==32)return m;}throw new Exception("Requested display mode is not supported");}
 public static void Apply(Mode mode) {int result=ChangeDisplaySettingsEx(null,ref mode,IntPtr.Zero,2,IntPtr.Zero);if(result!=0)throw new Exception("Display mode test failed: "+result); result=ChangeDisplaySettingsEx(null,ref mode,IntPtr.Zero,0,IntPtr.Zero);if(result!=0)throw new Exception("Display mode change failed: "+result);}
}
'@ }
$backup=Join-Path $PSScriptRoot 'display-before-game.json'
if ($Mode -eq '720p') {
 if (Test-Path -LiteralPath $backup) {
  $previous=Get-Content -LiteralPath $backup -Raw | ConvertFrom-Json
  if ($previous.Active) {
   $recovery=[GameDisplay]::Find([uint32]$previous.Width,[uint32]$previous.Height,[uint32]$previous.Frequency)
   [GameDisplay]::Apply($recovery)
  }
 }
 $current=[GameDisplay]::Read(-1)
 $target=[GameDisplay]::Find(1280,720,60)
 [pscustomobject]@{Width=$current.width;Height=$current.height;Frequency=$current.frequency;Active=$true} | ConvertTo-Json | Set-Content -LiteralPath $backup -Encoding UTF8
 [GameDisplay]::Apply($target)
} else {
 if (-not (Test-Path -LiteralPath $backup)) {
  Write-Host 'No saved display change exists; nothing to restore.'
  exit 0
 }
 $saved=Get-Content -LiteralPath $backup -Raw | ConvertFrom-Json
 $target=[GameDisplay]::Find([uint32]$saved.Width,[uint32]$saved.Height,[uint32]$saved.Frequency)
 [GameDisplay]::Apply($target)
 $saved.Active=$false
 $saved | ConvertTo-Json | Set-Content -LiteralPath $backup -Encoding UTF8
}
[GameDisplay]::Read(-1) | Select-Object width,height,frequency | ConvertTo-Json
