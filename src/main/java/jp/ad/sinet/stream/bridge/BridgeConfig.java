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
import org.yaml.snakeyaml.constructor.SafeConstructor;
import org.yaml.snakeyaml.Yaml;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.IOException;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import java.util.List;


// @SuppressWarnings("WeakerAccess")

@Log
class BridgeConfig {

    String bridgeServiceName;

    Map<String, Map<String, Object>> readerConfigList;  // bridge.reader
    Map<String, Map<String, Object>> writerConfigList;  // bridge.writer

    static final int maxQLenDefault = 1;
    int maxQLen = maxQLenDefault;  // bridge.max_qlen

    static final int retryConnectMaxDefault = 3;
    static final int retryConnectMinDelayDefault = 1;
    static final int retryConnectMaxDelayDefault = 64;
    int retryConnectMax = retryConnectMaxDefault;  // bridge.error.retrty_connect_max
    int retryConnectMinDelay = retryConnectMinDelayDefault;  // bridge.error.retrty_connect_min_delay [sec]
    int retryConnectMaxDelay = retryConnectMaxDelayDefault;  // bridge.error.retrty_connect_max_delay [sec]
    String reportServiceName;  // bridge.error.report
    Map<String, Object> reportConfig;  // bridge.error.report


    static <T> T[] makeArray(T... xs) {
        return xs;
    }

    static boolean not(boolean x) {
        return !x;
    }

    static <T> T getT(Map<String, Object> map, String key, Class<T> cls) {
        if (map == null)
            throw new RuntimeException("map shoud not be null");
        if (map.containsKey(key)) {
            try {
                return cls.cast(map.get(key));
            }
            catch (ClassCastException e) {
                throw new RuntimeException(key + ": type mismatch", e);
            }
        }
        throw new RuntimeException(String.format("map doesn't have '%s'", key));
    }

    static <T> T getT(Map<String, Object> map, String key, Class<T> cls, T dflt) {
        if (map == null)
            throw new RuntimeException("map shoud not be null");
        if (map.containsKey(key)) {
            try {
                return cls.cast(map.get(key));
            }
            catch (ClassCastException e) {
                throw new RuntimeException(key + ": type mismatch", e);
            }
        }
        return dflt;
    }

    class ConfigError extends RuntimeException {
        ConfigError(String s) {
            super("Invalid config file: " + s);
        }
    }

    BridgeConfig(File configFile, String bridgeServiceName) throws IOException {
        this.bridgeServiceName = bridgeServiceName;
        loadConfig(configFile);
    }

    void loadConfig(File file) throws IOException {
	InputStream input = new FileInputStream(file);
        Yaml yaml = new Yaml(new SafeConstructor());
        parseData(yaml.load(input));
    }

    private void parseData(Object data) {
	if (not(data instanceof Map))
	    throw new ConfigError("config file must be map");
	parseConfig((Map<String, Object>) data);
    }

    private void parseConfig(Map<String, Object> config) {
        if (not(config.containsKey("header")))
            throw new ConfigError("header: doesn't exist in the config file; the config file must be written in the format version >= 2.");
	int ver = parseHeaderPart(getT(config, "header", Map.class));
        switch (ver) {
	case 2: parseConfigPart(getT(config, "config", Map.class));
        }
    }

    private int parseHeaderPart(Map<String, Object> headerPart) {
	Object version = headerPart.get("version");
        if (version == null)
            return 2;
	if (not(version instanceof Integer))
	    throw new ConfigError("version must be integer");
        Integer ver = (Integer) version;
        if (ver != 2)
	    throw new ConfigError("version must be 2");
        return ver;
    }

    private void parseConfigPart(Map<String, Object> configPart) {
        Map<String, Object> params = bridgeServiceName == null ? getBridgeServiceParams(configPart)
                                                               : getBridgeServiceParams(configPart, bridgeServiceName);
        Map<String, Object> bridgeServiceParams;
        bridgeServiceParams = parseBridgeServiceParams(params);
        log.fine(() -> String.format("bridgeServiceName=%s", bridgeServiceName));
        log.fine(() -> String.format("bridgeServiceParams=%s", bridgeServiceParams));

        setupBridgeParams(bridgeServiceParams, configPart);
    }

    private Map<String, Object> getBridgeServiceParams(Map<String, Object> configPart) {
        String serviceName1 = null;
        Map<String, Object> serviceParams1 = null;
        for (Map.Entry<String, Object> s : configPart.entrySet()) {
            if (not(s.getValue() instanceof Map))
                continue;
            Map<String, Object> m = (Map<String, Object>) s.getValue();
            if ("bridge".equals(m.get("type"))) {
                if (serviceName1 != null)
                    throw new ConfigError("bridge definition must be only once");
                serviceName1 = s.getKey();
                serviceParams1 = m;
            }
        }
        if (serviceName1 == null)
            throw new ConfigError("bridge parameters must be defined");
        this.bridgeServiceName = serviceName1;
        return serviceParams1;
    }
    private Map<String, Object> getBridgeServiceParams(Map<String, Object> configPart, String serviceName) {
        Map<String, Object> serviceParams = getT(configPart, serviceName, Map.class);
        String typeValue = getT(serviceParams, "type", String.class);
        if (not("bridge".equals(typeValue)))
            throw new ConfigError(serviceName + ".type must be bridge");
        return serviceParams;
    }

    private Map<String, Object> parseBridgeServiceParams(Map<String, Object> bridgeParams) {
        return getT(bridgeParams, "bridge", Map.class);
    }

    private void setupBridgeParams(Map<String, Object> bridgeServiceParams, Map<String, Object> configPart) {
        this.writerConfigList = collectConfig(configPart, getT(bridgeServiceParams, "writer", List.class));
        this.readerConfigList = collectConfig(configPart, getT(bridgeServiceParams, "reader", List.class));
        if (this.writerConfigList == null || this.writerConfigList.isEmpty())
            throw new RuntimeException("writer must be defined");
        if (this.readerConfigList == null || this.readerConfigList.isEmpty())
            throw new RuntimeException("reader must be defined");

        Map<String, Object> retryParams = getT(bridgeServiceParams, "retry", Map.class, null);
        if (retryParams != null) {
            this.retryConnectMax = getT(retryParams, "connect_max", Integer.class, retryConnectMaxDefault);
            this.retryConnectMinDelay = getT(retryParams, "connect_min_delay", Integer.class, retryConnectMinDelayDefault);
            this.retryConnectMaxDelay = getT(retryParams, "connect_max_delay", Integer.class, retryConnectMaxDelayDefault);
        }

        this.reportServiceName = getT(bridgeServiceParams, "report", String.class, null);
        if (this.reportServiceName != null) {
            this.reportConfig = getT(configPart, this.reportServiceName, Map.class);
        }

        this.maxQLen = getT(bridgeServiceParams, "max_qlen", Integer.class, maxQLenDefault);
    }

    private Map<String, Map<String, Object>> collectConfig(Map<String, Object> configPart, List<String> serviceNameList) {
        if (serviceNameList == null)
            return null;
        Map<String, Map<String, Object>> configList = new HashMap<>();
        for (String s : serviceNameList) {
             Map<String, Object> c = getT(configPart, s, Map.class);
             configList.put(s, c);
        }
        return configList;
    }
}
