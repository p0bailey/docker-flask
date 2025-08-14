#!/usr/bin/env python3
from flask import render_template, jsonify, send_file
from flask import Flask
import os
import json

app = Flask(__name__)

@app.route('/')
def hello():
    return render_template('app.html')

@app.route('/security')
def security_report():
    return render_template('security-report.html')

@app.route('/api/security-report/<report_name>')
def get_security_report(report_name):
    """API endpoint to serve security report JSON data"""
    try:
        # Map report names to file paths
        report_files = {
            'image-scan': 'reports/image-scan.json',
            'dockerfile-scan': 'reports/dockerfile-scan.json', 
            'fs-scan': 'reports/fs-scan.json'
        }
        
        if report_name not in report_files:
            return jsonify({"error": "Report not found"}), 404
            
        # Get the absolute path to the report file
        report_path = os.path.join(os.path.dirname(__file__), report_files[report_name])
        
        if not os.path.exists(report_path):
            return jsonify({"error": "Report file not found", "path": report_path}), 404
            
        with open(report_path, 'r') as f:
            report_data = json.load(f)
            
        return jsonify(report_data)
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/security-summary')
def security_summary():
    """API endpoint to get security summary statistics"""
    try:
        summary = {
            'total_vulnerabilities': 0,
            'critical': 0,
            'high': 0, 
            'medium': 0,
            'low': 0,
            'last_scan': None,
            'reports_available': []
        }
        
        # Check which reports exist
        report_files = {
            'image-scan': 'reports/image-scan.json',
            'dockerfile-scan': 'reports/dockerfile-scan.json',
            'fs-scan': 'reports/fs-scan.json'
        }
        
        base_path = os.path.dirname(__file__)
        
        for report_name, report_file in report_files.items():
            report_path = os.path.join(base_path, report_file)
            if os.path.exists(report_path):
                summary['reports_available'].append(report_name)
                
                try:
                    with open(report_path, 'r') as f:
                        data = json.load(f)
                        
                    # Count vulnerabilities
                    if 'Results' in data:
                        for result in data['Results']:
                            if 'Vulnerabilities' in result:
                                for vuln in result['Vulnerabilities']:
                                    summary['total_vulnerabilities'] += 1
                                    severity = vuln.get('Severity', '').upper()
                                    if severity == 'CRITICAL':
                                        summary['critical'] += 1
                                    elif severity == 'HIGH':
                                        summary['high'] += 1
                                    elif severity == 'MEDIUM':
                                        summary['medium'] += 1
                                    elif severity == 'LOW':
                                        summary['low'] += 1
                                        
                            if 'Misconfigurations' in result:
                                for misc in result['Misconfigurations']:
                                    summary['total_vulnerabilities'] += 1
                                    severity = misc.get('Severity', '').upper()
                                    if severity == 'CRITICAL':
                                        summary['critical'] += 1
                                    elif severity == 'HIGH':
                                        summary['high'] += 1
                                    elif severity == 'MEDIUM':
                                        summary['medium'] += 1
                                    elif severity == 'LOW':
                                        summary['low'] += 1
                except:
                    continue
        
        return jsonify(summary)
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0')
