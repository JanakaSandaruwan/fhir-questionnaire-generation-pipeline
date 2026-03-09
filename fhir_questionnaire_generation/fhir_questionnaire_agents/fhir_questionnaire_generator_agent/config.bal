// Copyright (c) 2023, WSO2 LLC. (http://www.wso2.com).

// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at

// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/os;

// Environment variable helpers
function getEnvOrDefault(string key, string defaultVal) returns string {
    string val = os:getEnv(key);
    return val == "" ? defaultVal : val;
}

function getEnvAsIntOrDefault(string key, int defaultVal) returns int {
    string val = os:getEnv(key);
    if val == "" {
        return defaultVal;
    }
    int|error intVal = int:fromString(val);
    return intVal is int ? intVal : defaultVal;
}

final string ANTHROPIC_API_KEY = os:getEnv("ANTHROPIC_API_KEY");
final string ANTHROPIC_GENERATOR_AGENT_AI_GATEWAY_URL = getEnvOrDefault("ANTHROPIC_GENERATOR_AGENT_AI_GATEWAY_URL", "https://api.anthropic.com/v1");
final int SERVICE_PORT = getEnvAsIntOrDefault("SERVICE_PORT", 7082);
