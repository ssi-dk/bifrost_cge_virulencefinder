from bifrostlib import common
from bifrostlib.datahandling import Sample
from bifrostlib.datahandling import SampleComponentReference
from bifrostlib.datahandling import SampleComponent
from bifrostlib.datahandling import Component
from bifrostlib.datahandling import Category
from typing import Dict
import os
import json

def extract_virulence(virulence: Category, results: Dict, component_name: str) -> None:
    file_name = "virulencefinder_results/data.json"
    file_key = common.json_key_cleaner(file_name)
    file_path = os.path.join(component_name, file_name)
    with open(file_path) as input:
        results_json = json.load(input)
    virulence_results = results_json['virulencefinder']['results']
    for species in virulence_results.keys():
        print(species)
        for gene_type in virulence_results[species].keys():
            if virulence_results[species][gene_type] == "No hit found":
                continue
            for gene in virulence_results[species][gene_type].keys():
                name = virulence_results[species][gene_type][gene]['virulence_gene']
                protein_function = virulence_results[species][gene_type][gene]['protein_function']
                coverage = virulence_results[species][gene_type][gene]['coverage']
                identity = virulence_results[species][gene_type][gene]['identity']
                variants = None # not implemented
                summary_dict = {'gene':name, 'protein_function':protein_function}
                report_dict = {'gene':name, 'coverage':coverage, 'identity':identity, 'variants':variants}
                virulence['summary']['virulence_genes'].append(summary_dict)
                virulence['report']['data'].append(report_dict)
    results[file_key]={}
    results[file_key]['virulence_genes'] = virulence['summary']['virulence_genes']

def datadump(samplecomponent_ref_json: Dict):
    samplecomponent_ref = SampleComponentReference(value=samplecomponent_ref_json)
    samplecomponent = SampleComponent.load(samplecomponent_ref)
    sample = Sample.load(samplecomponent.sample)
    
    virulence = samplecomponent.get_category("virulence")
    if virulence is None:
        virulence = Category(value={
                "name": "virulence",
                "component": {"id": samplecomponent["component"]["_id"], "name": samplecomponent["component"]["name"]},
                "summary": {'virulence_genes':[]},
                "report": {"data":[]}
            }
        )
    extract_virulence(virulence, samplecomponent["results"], samplecomponent["component"]["name"])
    samplecomponent.set_category(virulence)
    sample.set_category(virulence)
    common.set_status_and_save(sample, samplecomponent, "Success")
    
    with open(os.path.join(samplecomponent["component"]["name"], "datadump_complete"), "w+") as fh:
        fh.write("done")

datadump(
    snakemake.params.samplecomponent_ref_json,
)