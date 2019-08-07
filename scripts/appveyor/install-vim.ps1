If ($Env:VIM_VERSION -match "^nvim-v"){
    $nvimver = $Env:VIM_VERSION -replace "^nvim-v",""
    If ($nvimver -eq "latest"){
        choco install neovim --yes
    }Else{
        choco install neovim --yes --version "$nvimver"
    }
    $Env:THEMIS_VIM = "nvim.exe"
}Else{
    git clone -c advice.detachedHead=false https://github.com/vim/vim.git -q --branch "$Env:VIM_VERSION" --single-branch --depth 1 "$Env:TEMP\vim"
    Set-Location "$Env:TEMP\vim\src\"
    Set-Item Env:Path "C:\msys64\mingw64\bin\;$Env:Path"
    mingw32-make -j 2 -f Make_ming.mak FEATURES=HUGE ARCH=x86-64 MBYTE=yes GUI=no DEBUG=no
    Move-Item vim.exe ..\vim.exe
    $Env:THEMIS_VIM = "$Env:TEMP\vim\vim.exe"
    Set-Location "$Env:APPVEYOR_BUILD_FOLDER"
}
