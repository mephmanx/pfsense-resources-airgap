#!/bin/sh

install_pkg()
{
  pkg_name=$1

  yes | pkg install "$pkg_name"
  telegram_notify  "PFSense init: installed pkg -> $pkg_name"
}