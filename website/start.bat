@echo off
set PATH=C:\Program Files\nodejs;%PATH%
cd /d "%~dp0"
if not exist "node_modules" (
    echo node_modules not found, running npm install...
    npm install
)
npm start
