# script for use with snakemake
import subprocess
import traceback
from bifrostlib import common
from bifrostlib.datahandling import Component, Sample
from bifrostlib.datahandling import SampleComponentReference
from bifrostlib.datahandling import SampleComponent
from bifrostlib.datahandling import Category
from typing import Dict
import os


def run_cmd(command, log):
    with open(log.out_file, "a+") as out, open(log.err_file, "a+") as err:
        command_log_out, command_log_err = subprocess.Popen(command, shell=True).communicate()
        if command_log_err == None:
            command_log_err = ""
        if command_log_out == None:
            command_log_out = ""
        out.write(command_log_out)
        err.write(command_log_err)

def rule__run_cge_mlst(input: object, output: object, samplecomponent_ref_json: Dict, log: object) -> None:
    try:
        samplecomponent_ref = SampleComponentReference(value=samplecomponent_ref_json)
        samplecomponent = SampleComponent.load(samplecomponent_ref)
        sample = Sample.load(samplecomponent.sample)
        component = Component.load(samplecomponent.component)

        # Variables being used
        database_path = component["resources"]["database_path"]
        reads = input.reads  # expected a tuple of read locations
        output_file = output.complete  # a file to mark success for snakemake
        species_detection = sample.get_category("species_detection")
        species = species_detection["summary"].get("species", None)
        # Code to run
        if species not in component["options"]["mlst_species_mapping"]:
            run_cmd(f"touch {component['name']}/no_mlst_species_DB")
        else:
            mlst_species = component["options"]["mlst_species_mapping"][species]
            data_dict = {}
            for mlst_entry in mlst_species:
                #print(mlst_entry)
                mlst_entry_path = f"{component['name']}/{mlst_entry}"
                #run_cmd("echo hello world", log)
                run_cmd(f"if [ -d \"{mlst_entry_path}\" ]; then rm -r {mlst_entry_path}; fi", log)
                #run_cmd(f"ls {database_path} -lah")
                run_cmd(f"mkdir {mlst_entry_path}; mlst.py -x -matrix -s {mlst_entry} -p {database_path} -mp kma -i {reads[0]} {reads[1]} -o {mlst_entry_path}", log) # this cmd looks fucked up
                data_dict[mlst_entry] = common.get_yaml(f"{mlst_entry_path}/data.json")
            common.save_yaml(data_dict, output_file)

    except Exception:
        with open(log.err_file, "w+") as fh:
            fh.write(traceback.format_exc())


rule__run_cge_mlst(
    snakemake.input,
    snakemake.output,
    snakemake.params.samplecomponent_ref_json,
    snakemake.log)
