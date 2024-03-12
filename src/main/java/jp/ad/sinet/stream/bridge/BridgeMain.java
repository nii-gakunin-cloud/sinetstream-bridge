/*
 * Copyright (C) 2023 National Institute of Informatics
 *
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package jp.ad.sinet.stream.bridge;

import lombok.extern.java.Log;

import org.apache.commons.cli.*;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.logging.LogManager;
import java.util.Optional;


// @SuppressWarnings("WeakerAccess")
@Log
public class BridgeMain {

    static private void readConfig(String serviceName, File configFile) throws IOException {
        BridgeConfig bridgeConfig = new BridgeConfig(configFile, serviceName);
        BridgeServer bridgeServer = new BridgeServer(bridgeConfig);
        bridgeServer.start();
        // never reach
    }

    static final String[] configFileListDefault = {
        "./.sinetstream_config.yml",
        System.getProperty("user.home") + "/.config/sinetstream/config.yml",
    };

    /*
    static private void testlog() {
        log.warning("testlog:loglevel=warning");
        log.info("testlog:loglevel=info");
        log.config("testlog:loglevel=config");
        log.fine("testlog:loglevel=fine");
        log.finer("testlog:loglevel=finer");
        log.finest("testlog:loglevel=finest");
    }
    */

    static private void init(CommandLine cmdLine) {
        String serviceName = cmdLine.getOptionValue("service");
        if (cmdLine.hasOption("log-prop-file")) {
            String logPropFile = cmdLine.getOptionValue("log-prop-file");
            try {
                LogManager.getLogManager().readConfiguration(new FileInputStream(logPropFile));
            }
            catch (Exception ex) {
                BridgeLogMsg.configError(logPropFile, "error in reading the logging properties: " + Util.getStackTrace(ex));
                BridgeLogMsg.terminated(serviceName, null);
                Util.exit(1, 0);
            }
        }
        String[] configFileList = Optional.ofNullable(cmdLine.getOptionValues("config-file")).orElse(configFileListDefault);
        //testlog();
        for (String file : configFileList) {
            try {
                readConfig(serviceName, new File(file));
                // never reach
                return;
            } catch (java.io.FileNotFoundException ex) {
                BridgeLogMsg.configError(file, "not found");
            } catch (BridgeConfig.ConfigError ex) {
                BridgeLogMsg.configError(file, "error in reading the config file: "  + Util.getStackTrace(ex));
            } catch (IOException ex) {
                BridgeLogMsg.configError(file, "I/O error in reading the config file: " + Util.getStackTrace(ex));
            }
        }
        BridgeLogMsg.configError(serviceName, "No valid config file exists");
        BridgeLogMsg.terminated(serviceName, null);
        Util.exit(1, 0);
    }

    private static void parseArgs(String[] args) {
        Options opts = new Options();
        opts.addOption(Option.builder("h").longOpt("help")
                                       .desc("this help")
                                       .build());
        opts.addOption(Option.builder("s").longOpt("service")
                                       .hasArg().argName("SERVICE")
                                       .desc("specify the service name")
                                       .build());
        opts.addOption(Option.builder("f").longOpt("config-file")
                                       .hasArg().argName("FILE")
                                       .desc("specify the config file")
                                       .build());
        opts.addOption(Option.builder("lp").longOpt("log-prop-file")
                                       .hasArg().argName("FILE")
                                       .desc("read the specfied logging proerties file ")
                                       .build());
        try {
            CommandLineParser parser = new DefaultParser();
            CommandLine cmdLine = parser.parse(opts, args);
            if (cmdLine.hasOption("help"))
                printHelp(opts);
            init(cmdLine);
        } catch (ParseException ex) {
            System.err.println("Parsing failed: " + Util.getStackTrace(ex));
            printHelp(opts);
	}
    }

    static void printHelp(Options opts) {
        new HelpFormatter().printHelp("sinetstream-bridge [--option ...]", opts);
        Util.exit(1, 0);
    }

    public static void main(String[] args) {
        try {
            LogManager.getLogManager().readConfiguration(BridgeMain.class.getResourceAsStream("log.prop"));
            parseArgs(args);
        }
        catch (Throwable t) {
            BridgeLogMsg.terminated(null, Util.getStackTrace(t));
            Util.exit(1);
        }
        BridgeLogMsg.terminated(null, "NEVER REACH");
        Util.exit(1);
    }
}
