import os
import sys
import platform
from jproperties import Properties
import http.client
import mimetypes
import base64
import json
import re
import uuid
import urllib.parse

os_name = platform.system()

if os_name == "Windows":
    print("OS: Windows")
else:
    sys.exit(1)

# Load config
with open("config.properties", "r+b") as f:
    p = Properties()
    p.load(f, "utf-8")

    hawkbit_domain = p.properties.get("hawkbit.domain")
    if hawkbit_domain.startswith("https://"):
        hawkbit_domain = hawkbit_domain[len("https://"):]
    hawkbit_username = p.properties.get("hawkbit.username")
    hawkbit_password = p.properties.get("hawkbit.password")
    hawkbit_gatewaysecuritytoken = p.properties.get("hawkbit.gateway-security-token")
    global hawkbit_devicetargetid 
    hawkbit_devicetargetid = p.properties.get("hawkbit.device-target-id")
    hawkbit_devicesecuritytoken = p.properties.get("hawkbit.device-security-token")


class ReqMethod:
    GET = "GET"
    PUT = "PUT"
    POST = "POST"


def fetch(conn, method, url, body=None, headers=None, no_rep=False):
    parsed_json = None
    try:
        conn.request(method, url, body=body, headers=headers)
        response = conn.getresponse()
        data = response.read()
        if data == b'' and response.code == 200:
            json_data = data.decode('utf-8')
            parsed_json = json.loads("{}")    
        else:
            json_data = data.decode('utf-8')
            parsed_json = json.loads(json_data)
    except Exception as e:
        msg = f"An error occurred: {e}"
        print(msg)
    finally:
        conn.close()
    
    return parsed_json


def print_fjson(parsed_json):
    formatted_json = json.dumps(parsed_json, indent=4)
    print(formatted_json)


def get_next_devicetargetid(input_string):
    match = re.search(r'(\D*)(\d+)', input_string)
    if match:
        prefix = match.group(1)
        nd = int(match.group(2)) + 1
        formatted_number = f"{nd:02}"
        return prefix + formatted_number
    return input_string
    # match = re.search(r'\d+', input_string)
    # nd = 0
    # if match:
    #     nd = int(match.group(0))
    # nd += 1
    # formatted_number = f"{nd:02}"
    # return formatted_number

def get_num_devicetargetid(input_string):
    match = re.search(r'\d+', input_string)
    nd = 0
    if match:
        nd = int(match.group(0))    
    return nd


def test_single_device():
    print(hawkbit_domain)
    print(hawkbit_username)
    print(hawkbit_password)
    print(hawkbit_devicetargetid)
    auth = base64.b64encode(f"{hawkbit_username}:{hawkbit_password}".encode()).decode()
    conn = http.client.HTTPSConnection(hawkbit_domain)
    url = "/rest/v1/system/configs/authentication.targettoken.enabled/"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Basic {auth}"
    }

    parsed_json = fetch(conn, ReqMethod.GET, url, headers=headers)
    print_fjson(parsed_json)
    value = parsed_json.get("value")
    if value != True:
        url = "/rest/v1/system/configs/authentication.targettoken.enabled/"
        body = json.dumps({"value": True})
        parsed_json = fetch(conn, ReqMethod.PUT, url, body=body, headers=headers)
        print_fjson(parsed_json)

    url = "/rest/v1/system/configs/authentication.gatewaytoken.enabled/"
    parsed_json = fetch(conn, ReqMethod.GET, url, headers=headers)
    print_fjson(parsed_json)
    value = parsed_json.get("value")
    print(f"value={value}")
    if value != True:
        url = "/rest/v1/system/configs/authentication.gatewaytoken.enabled/"
        body = json.dumps({"value": True})
        parsed_json = fetch(conn, ReqMethod.PUT, url, body=body, headers=headers)
        print_fjson(parsed_json)

    url = "/rest/v1/system/configs/authentication.gatewaytoken.key/"
    body = json.dumps({"value": hawkbit_gatewaysecuritytoken})
    parsed_json = fetch(conn, ReqMethod.PUT, url, body=body, headers=headers)
    print_fjson(parsed_json)

    devicetargetid = hawkbit_devicetargetid
    devicetargetid_found = False

    while devicetargetid_found == False:
        url = f"/rest/v1/targets/{devicetargetid}"
        parsed_json = fetch(conn, ReqMethod.GET, url, headers=headers)
        print_fjson(parsed_json)
        if "errorCode" in parsed_json:
            error_code = parsed_json.get("errorCode")
            print(f"errorCode={error_code}")
            if "entitiyNotFound" in error_code:
                devicetargetid_found = True
            else:
                sys.exit(1)
        else:               
            devicetargetid = get_next_devicetargetid(devicetargetid)
    
    num_devicetargetid = get_num_devicetargetid(devicetargetid)

    url = "/rest/v1/targets"
    body = json.dumps([{"controllerId": devicetargetid,
                       "name": f"EDevice {num_devicetargetid}",
                       "description": f"Emu device {num_devicetargetid}",
                       "securityToken": hawkbit_devicesecuritytoken}])
    parsed_json = fetch(conn, ReqMethod.POST, url, body=body, headers=headers)
    print_fjson(parsed_json)

    url = f"/DEFAULT/controller/v1/{devicetargetid}"
    headers = {
        "Authorization": f"TargetToken {hawkbit_devicesecuritytoken}"
    }
    parsed_json = fetch(conn, ReqMethod.GET, url, headers=headers)
    print_fjson(parsed_json)

    url = f"/DEFAULT/controller/v1/{devicetargetid}/configData"
    headers = {
        "Authorization": f"TargetToken {hawkbit_devicesecuritytoken}",
        "Content-Type": "application/json"
    }
    body = json.dumps({"mode": "merge",
                       "data": {"PN": "BD01", "HWRev": "1.0"}})
    parsed_json = fetch(conn, ReqMethod.PUT, url, body=body, headers=headers)
    print_fjson(parsed_json)

    url = "/rest/v1/softwaremodules"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Basic {auth}"
    }
    body = json.dumps([{"vendor": "Bitdove Ltd.",
                       "name": f"BitdoveOS {num_devicetargetid}",
                       "description": "First version of BitdoveOS.",
                       "type": "os",
                       "version": "1.0"}])
    parsed_json = fetch(conn, ReqMethod.POST, url, body=body, headers=headers)
    print_fjson(parsed_json)
    soft_module_id = parsed_json[0].get("id")
    print(f"soft_module_id={soft_module_id}")

    url = "/rest/v1/softwaremodules?q=name==BitdoveOS*"
    print(url)
    parsed_json = fetch(conn, ReqMethod.GET, url, headers=headers)
    print_fjson(parsed_json)

    url = f"/rest/v1/softwaremodules?q=id=={soft_module_id}"
    print(url)
    parsed_json = fetch(conn, ReqMethod.GET, url, headers=headers)
    print_fjson(parsed_json)
    
    text_to_write = "This is a test update file."
    file_name = f"artifact{num_devicetargetid}.txt"
    script_dir = os.path.dirname(os.path.abspath(__file__))
    file_path = os.path.join(script_dir, file_name)
    with open(file_path, 'w') as file:
        file.write(text_to_write)
    print(f"Gen={file_path}")
    file_size = os.path.getsize(file_path)

    url = f"/rest/v1/softwaremodules/{soft_module_id}/artifacts"
    # Not Support

    # headers = {
    #     "Content-Type": "application/octet-stream",
    #     "Content-Disposition": 'attachement; filename="{file_name}"',
    #     "Content-Length": str(file_size),
    #     "Authorization": f"Basic {auth}"
    # }
    # conn.request(ReqMethod.POST, url, headers=headers)
    # with open(file_path, 'rb') as file:
    #     conn.send(file.read())
    # response = conn.getresponse()
    # data = response.read()
    # json_data = data.decode('utf-8')
    # parsed_json = json.loads(json_data)
    # print_fjson(parsed_json)

    # body = json.dumps([{"controllerId": devicetargetid,
    #                    "name": f"EDevice {num_devicetargetid}",
    #                    "description": f"Emu device {num_devicetargetid}",
    #                    "securityToken": hawkbit_devicesecuritytoken}])
    
    # Work fine

    # hash = str(uuid.uuid4())
    boundary = f"----WebKitFormBoundary{str(uuid.uuid4())}"
    headers = {
        'Content-Type': f"multipart/form-data; boundary={boundary}",
        "Authorization": f"Basic {auth}"
    }
    with open(file_path, 'rb') as file:
        file_content = file.read()
    body = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="file"; filename="{file_name}"\r\n'
        f"Content-Type: Content-Type: text/plain\r\n"
        "\r\n"
        f"{file_content.decode('utf-8')}\r\n"
        f'--{boundary}--\r\n'
    )
    parsed_json = fetch(conn, ReqMethod.POST, url, body=body, headers=headers)
    print_fjson(parsed_json)
    artifact_id = parsed_json.get("id")
    print(f"artifact_id={artifact_id}")

    url = f"/rest/v1/softwaremodules/{soft_module_id}/artifacts/{artifact_id}/download"
    headers = {
        "Authorization": f"Basic {auth}"
    }
    conn.request("GET", url, headers=headers)
    response = conn.getresponse()
    if response.status == 200:
        file_content = response.read()
        file_name = f"artifact{num_devicetargetid}-test.txt"    
        script_dir = os.path.dirname(os.path.abspath(__file__))
        file_path = os.path.join(script_dir, file_name)
        with open(file_path, 'wb') as file:
            file.write(file_content)    
        print(f"Dw={file_path}")
    else:
        print(f"Dw failed, code={response.status}, res={response.reason}")
        sys.exit(1)
    
    url = "/rest/v1/distributionsets"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Basic {auth}"
    }
    body = json.dumps([{"requiredMigrationStep": False,
                       "name": f"DistOS {num_devicetargetid}",
                       "description": "First distribution.",
                       "type": "os_app",
                       "version": "1.0"}])
    parsed_json = fetch(conn, ReqMethod.POST, url, body=body, headers=headers)
    print_fjson(parsed_json)
    distribution_id = parsed_json[0].get("id")
    print(f"distribution_id={distribution_id}")

    url = f"/rest/v1/distributionsets/{distribution_id}/assignedSM"
    body = json.dumps([{"id": soft_module_id}])
    parsed_json = fetch(conn, ReqMethod.POST, url, body=body, headers=headers, no_rep=True)
    print(f"Assigning a Software Module Success")

    url = f"/rest/v1/distributionsets/{distribution_id}/assignedTargets/"
    headers = {
        "Content-Type": "application/hal+json;charset=UTF-8",
        "Authorization": f"Basic {auth}"
    }
    body = json.dumps([{"id": devicetargetid,
                       "type": "forced"}])
    parsed_json = fetch(conn, ReqMethod.POST, url, body=body, headers=headers)
    print_fjson(parsed_json)
    assigned = parsed_json.get("assigned")
    print(f"assigned={assigned}")
    action_id = parsed_json.get("assignedActions")[0].get("id")
    print(f"action_id={action_id}")

    url = f"/DEFAULT/controller/v1/{devicetargetid}"
    headers = {
        "Authorization": f"TargetToken {hawkbit_devicesecuritytoken}",
        "Content-Type": "application/json"
    }
    parsed_json = fetch(conn, ReqMethod.GET, url, headers=headers)
    print_fjson(parsed_json)
    links_href = parsed_json.get("_links").get("deploymentBase").get("href")
    print(f"links_href={links_href}")
    parsed_url = urllib.parse.urlparse(links_href)
    path_parts = parsed_url.path.split('/')
    if path_parts[-1] == str(action_id):
        query_params = urllib.parse.parse_qs(parsed_url.query)
        if 'c' in query_params:
            action_code = query_params['c'][0]
        else:
            print(f"No action code.")
            sys.exit(1)
    else:
        print(f"action_id error.")
        sys.exit(1)
    print(f"action_code={action_code}")

    url = f"/DEFAULT/controller/v1/{devicetargetid}"
    headers = {
        "Authorization": f"TargetToken {hawkbit_devicesecuritytoken}",
        "Content-Type": "application/json"
    }
    parsed_json = fetch(conn, ReqMethod.GET, url, headers=headers)
    print_fjson(parsed_json)

    url = f"/DEFAULT/controller/v1/{devicetargetid}/deploymentBase/{action_id}?c={action_code}"
    headers = {
        "Authorization": f"TargetToken {hawkbit_devicesecuritytoken}",
        "Content-Type": "application/json"
    }
    parsed_json = fetch(conn, ReqMethod.GET, url, headers=headers)
    print_fjson(parsed_json)
    links_href = parsed_json.get("deployment").get("chunks")[0].get("artifacts")[0].get("_links").get("download-http").get("href")
    print_fjson(links_href)

    url = f"/DEFAULT/controller/v1/{devicetargetid}/softwaremodules/{soft_module_id}/artifacts/artifact{num_devicetargetid}.txt"
    headers = {
        "Authorization": f"TargetToken {hawkbit_devicesecuritytoken}",
    }
    conn.request(ReqMethod.GET, url, headers=headers)
    response = conn.getresponse()
    if response.status == 200:
        file_content = response.read()
        file_name = f"artifact{num_devicetargetid}-dw.txt"    
        script_dir = os.path.dirname(os.path.abspath(__file__))
        file_path = os.path.join(script_dir, file_name)
        with open(file_path, 'wb') as file:
            file.write(file_content)    
        print(f"Dw={file_path}")
    else:
        print(f"Dw failed, code={response.status}, res={response.reason}")
        sys.exit(1)
    with open(file_path, 'rb') as file:
        file_content = file.read()
    if file_content.decode('utf-8') == "This is a test update file.":
        print("DW content correct.")
    else:
        print(f"Dw content error.")
        sys.exit(1)

    url = f"/DEFAULT/controller/v1/{devicetargetid}/deploymentBase/{action_id}/feedback"
    headers = {
        "Authorization": f"TargetToken {hawkbit_devicesecuritytoken}",
        "Content-Type": "application/json;charset=UTF-8"
    }
    body = json.dumps({"id": action_id,
                       "status": {
                           "result": {
                               "progress": {
                                   "cnt": 2,
                                   "of": 5
                               },
                               "finished": "none"
                           },
                           "execution": "proceeding",
                           "details": ["The update is being processed."]
                       }})
    parsed_json = fetch(conn, ReqMethod.POST, url, headers=headers, body=body, no_rep=True)


    url = f"/DEFAULT/controller/v1/{devicetargetid}/deploymentBase/{action_id}/feedback"
    headers = {
        "Authorization": f"TargetToken {hawkbit_devicesecuritytoken}",
        "Content-Type": "application/json;charset=UTF-8"
    }
    body = json.dumps({"id": action_id,
                       "status": {
                           "result": {
                               "finished": "success"
                           },
                           "execution": "closed",
                           "details": ["The update was successfully installed."]
                       }})
    parsed_json = fetch(conn, ReqMethod.POST, url, headers=headers, body=body, no_rep=True)


if __name__ == "__main__":
    test_single_device()