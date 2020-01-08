/*
 * %FFILE%
 * Copyright (C) %YEAR% %USER% <%MAIL%>
 *
 * Distributed under terms of the %LICENSE% license.
 */

plugins {
    %HERE%
}

repositories {
    jcenter()
}

dependencies {
    //implementation(files("libs/something.jar"))
}

tasks {
    test {
        testLogging {
            showExceptions = true
            showStackTraces = true
            showStandardStreams = true
        }
    }
}
