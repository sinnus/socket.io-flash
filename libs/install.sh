#! /bin/bash
mvn install:install-file -Dfile=as3corelib.swc -DgroupId=com.adobe -DartifactId=as3corelib -Dversion=1.0 -Dpackaging=swc
mvn install:install-file -Dfile=WebSocketMain.swf -DgroupId=net.gimite -DartifactId=websocket -Dversion=1.0 -Dpackaging=swc
