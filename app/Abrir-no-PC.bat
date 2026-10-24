@echo off
chcp 65001 >nul
setlocal
title Guardiao Gamer - alpha 0.1
set "APP=%~dp0index.html"
if not exist "%APP%" set "APP=%~dp0app\index.html"
if not exist "%APP%" (
  echo Nao encontrei o index.html. Extraia o ZIP inteiro antes de abrir este arquivo.
  pause
  exit /b 1
)
set "URL=%APP:\=/%"
set "URL=file:///%URL%"
rem Tenta abrir como janela de aplicativo (sem barra de enderecos) no Edge ou no Chrome.
start "" msedge --app="%URL%" --window-size=460,940 2>nul && exit /b 0
start "" chrome --app="%URL%" --window-size=460,940 2>nul && exit /b 0
rem Plano B: abre no navegador padrao.
start "" "%APP%"
exit /b 0
