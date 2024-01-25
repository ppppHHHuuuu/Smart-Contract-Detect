

# check if each in overlapping has X error 
    # if yes => files/X/
    # if no => 
import json
import os
import re
import shutil
src_path= os.path.join(os.path.abspath(os.getcwd()), "files")
dest_issue_path= os.path.join(os.path.abspath(os.getcwd()), "survey", "issue")
dest_no_issue_path= os.path.join(os.path.abspath(os.getcwd()), "survey", "noissue")

issue_names: list[str] = ["TD", "RE", "UpS", "IOU", "DC", "NC", "TO", "TOD", "UpS", "FE", "UcC"]
def check_issue():
    with open('f.json', "r") as f:
        data = json.loads(f.read())
        files_name: dict[str, dict] = data["contract_name"]
        
        for file_idx in files_name:
            issues:dict[str, str] = json.loads(data["overlapping"][file_idx])
            print (file_idx)
            print(issues)
            for inner_ID in issues:
                print(inner_ID)
                add_file_to_issue_category(file_idx, inner_ID)
def check_no_issue():
    with open('f.json', "r") as f:
        data = json.loads(f.read())
        files_name: dict[str, dict] = data["contract_name"]

        for file_idx in files_name:
            issues:dict[str, str] = json.loads(data["overlapping"][file_idx])
            issue_list: list[str] = []
            # print(issues)
            for inner_ID in issues:
                issue_list.append(inner_ID)
            for issue_name in issue_names:
                
                if (issue_name not in issue_list):
                    add_file_to_notIssue_category(file_idx, issue_name)
                    
                
        
                    

def add_file_to_issue_category(file_index:str, issue_type):
    for (root, dirs, files) in os.walk(src_path):
        for file in files:
            (file_name, type) = os.path.splitext(file)
            number = file_name.split("-")[1]

            if (number == file_index):
                # print(number, " ", file_index)

                src = os.path.join(src_path, file)
                dest = os.path.join(dest_issue_path, issue_type, file)
                shutil.copy(src, dest)
                    
def add_file_to_notIssue_category(file_index:str, issue_type):
    for (root, dirs, files) in os.walk(src_path):
        for file in files:
            (file_name, type) = os.path.splitext(file)
            number = file_name.split("-")[1]

            if (number == file_index):
                # print(number, " ", file_index)

                src = os.path.join(src_path, file)
                dest = os.path.join(dest_no_issue_path, issue_type, file)
                shutil.copy(src, dest)
            
check_no_issue()
# add_file_to_notIssue_category('35', "IOU")