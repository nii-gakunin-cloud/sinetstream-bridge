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

@Log
class BridgeLogMsg {

    private static String appendix(String s) {
        return s == null ? "" : ": " + s;
    }

    // Process Level
    public static String configError(String svc, String comment) {
        String msg = String.format("SINETStream-Bridge:%s: ERROR IN THE CONFIG FILE", svc)
                   + appendix(comment);
        log.warning(msg);
        return msg;
    }
    public static String connectionError(String svc, String comment) {
        String msg = String.format("SINETStream-Bridge:%s: CONNECTION ERROR", svc)
                   + appendix(comment);
        log.severe(msg);
        return msg;
    }
    public static String started(String svc, String comment) {
        String msg = String.format("SINETStream-Bridge:%s: STARTED", svc)
                   + appendix(comment);
        log.info(msg);
        return msg;
    }
    public static String terminated(String svc, String comment) {
        String msg = String.format("SINETStream-Bridge:%s: TERMINATED", svc)
                   + appendix(comment);
        log.severe(msg);
        return msg;
    }
    /*
    public static String shutdown(String comment) {
        String msg = "SINETStream-Bridge: SHUTDOWN"
                   + appendix(comment);
        log.severe(msg);
        return msg;
    }
    */

    // Service Level
    public static String serviceDisconnected(String svc, String comment) {
        String msg = String.format("SINETStream-Bridge:%s: DISCONNECTED", svc)
                   + appendix(comment);
        log.warning(msg);
        return msg;
    }
    public static String serviceReconnecting(String svc, String comment) {
        String msg = String.format("SINETStream-Bridge:%s: RECONNECTING", svc)
                   + appendix(comment);
        log.warning(msg);
        return msg;
    }
    public static String serviceReconnected(String svc, String comment) {
        String msg = String.format("SINETStream-Bridge:%s: RECONNECTED", svc)
                   + appendix(comment);
        log.warning(msg);
        return msg;
    }
    /*
    public static String serviceReconnectFailure(String svc, String comment) {
        String msg = String.format("SINETStream-Bridge:%s: RECONNECT FAILURE", svc)
                   + appendix(comment);
        log.warning(msg);
        return msg;
    }
    */
    public static String serviceConnectionError(String svc, String comment) {
        String msg = String.format("SINETStream-Bridge:%s: CONNECTION ERROR", svc)
                   + appendix(comment);
        log.warning(msg);
        return msg;
    }
    public static String serviceTerminated(String svc, String comment) {
        String msg = String.format("SINETStream-Bridge:%s: TERMINATED", svc)
                   + appendix(comment);
        log.warning(msg);
        return msg;
    }
}
