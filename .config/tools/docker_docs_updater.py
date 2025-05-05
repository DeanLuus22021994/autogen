#!/usr/bin/env python3
"""
Docker Documentation XML Updater

This script allows easy addition and updating of Docker documentation links
in the .config/host/docker_documentation.xml file.
"""
import os
import sys
import xml.etree.ElementTree as ET
from datetime import datetime
import argparse

def get_xml_path():
    """Get the path to the docker_documentation.xml file."""
    # Determine if we're in the autogen repo root or elsewhere
    if os.path.isdir('.config'):
        return os.path.join('.config', 'host', 'docker_documentation.xml')
    else:
        # Try to find the autogen repo root
        current_dir = os.getcwd()
        while current_dir != os.path.dirname(current_dir):  # Check if we're at filesystem root
            if os.path.isdir(os.path.join(current_dir, '.config')):
                return os.path.join(current_dir, '.config', 'host', 'docker_documentation.xml')
            current_dir = os.path.dirname(current_dir)

    # If we couldn't find it, use the default path
    return 'c:\\Projects\\autogen\\.config\\host\\docker_documentation.xml'

def add_link(args):
    """Add a new link to the XML file."""
    xml_path = get_xml_path()
    if not os.path.exists(xml_path):
        print(f"Error: XML file not found at {xml_path}")
        return 1

    # Parse the XML file
    tree = ET.parse(xml_path)
    root = tree.getroot()

    # Find the specified category
    category = None
    for cat in root.findall('.//category'):
        if cat.get('id') == args.category:
            category = cat
            break

    if category is None:
        print(f"Category '{args.category}' not found. Available categories:")
        for cat in root.findall('.//category'):
            print(f"  - {cat.get('id')}: {cat.find('name').text}")
        return 1

    # Check if the link ID already exists
    existing_links = root.findall('.//link')
    for link in existing_links:
        if link.get('id') == args.id:
            print(f"Error: Link ID '{args.id}' already exists. Choose a different ID.")
            return 1

    # Create new link element
    links = category.find('links')
    link = ET.SubElement(links, 'link', {'id': args.id})

    url = ET.SubElement(link, 'url')
    url.text = args.url

    title = ET.SubElement(link, 'title')
    title.text = args.title

    description = ET.SubElement(link, 'description')
    description.text = args.description

    last_validated = ET.SubElement(link, 'last_validated')
    last_validated.text = datetime.now().strftime('%Y-%m-%dT%H:%M:%SZ')

    # Add to tags if specified
    if args.tags:
        tags = args.tags.split(',')
        for tag_name in tags:
            tag_name = tag_name.strip()
            tag_elem = None

            # Find existing tag or create new one
            for existing_tag in root.findall('.//tag'):
                if existing_tag.get('name') == tag_name:
                    tag_elem = existing_tag
                    break

            if tag_elem is None:
                tags_elem = root.find('tags')
                tag_elem = ET.SubElement(tags_elem, 'tag', {'name': tag_name})

            # Add link reference to tag
            link_ref = ET.SubElement(tag_elem, 'link_ref')
            link_ref.text = args.id

    # Update metadata
    metadata = root.find('metadata')
    updated = metadata.find('updated')
    updated.text = datetime.now().strftime('%Y-%m-%dT%H:%M:%SZ')

    # Write back to file with proper formatting
    tree.write(xml_path, encoding='UTF-8', xml_declaration=True)

    # Add indentation (ElementTree doesn't preserve formatting)
    format_xml_file(xml_path)

    print(f"Successfully added link '{args.title}' with ID '{args.id}' to category '{args.category}'")
    if args.tags:
        print(f"Added to tags: {args.tags}")

    return 0

def list_resources(args):
    """List resources in the XML file."""
    xml_path = get_xml_path()
    if not os.path.exists(xml_path):
        print(f"Error: XML file not found at {xml_path}")
        return 1

    # Parse the XML file
    tree = ET.parse(xml_path)
    root = tree.getroot()

    if args.category:
        # List links in the specified category
        found = False
        for category in root.findall('.//category'):
            if category.get('id') == args.category:
                found = True
                name = category.find('name').text
                description = category.find('description').text
                print(f"Category: {name} ({args.category})")
                print(f"Description: {description}")
                print("\nLinks:")

                for link in category.findall('.//link'):
                    link_id = link.get('id')
                    title = link.find('title').text
                    url = link.find('url').text
                    desc = link.find('description').text
                    print(f"  - {link_id}: {title}")
                    print(f"    URL: {url}")
                    print(f"    Description: {desc}")
                    print()

                break

        if not found:
            print(f"Category '{args.category}' not found. Use --list without arguments to see all categories.")
            return 1

    elif args.tag:
        # List links with the specified tag
        found = False
        for tag in root.findall('.//tag'):
            if tag.get('name') == args.tag:
                found = True
                print(f"Links with tag '{args.tag}':")

                for link_ref in tag.findall('link_ref'):
                    link_id = link_ref.text
                    # Find the actual link
                    for link in root.findall('.//link'):
                        if link.get('id') == link_id:
                            title = link.find('title').text
                            url = link.find('url').text
                            print(f"  - {link_id}: {title}")
                            print(f"    URL: {url}")
                            print()
                            break

                break

        if not found:
            print(f"Tag '{args.tag}' not found. Use --list-tags to see all available tags.")
            return 1

    else:
        # List all categories
        print("Available categories:")
        for category in root.findall('.//category'):
            cat_id = category.get('id')
            name = category.find('name').text
            description = category.find('description').text
            link_count = len(category.findall('.//link'))
            print(f"  - {cat_id}: {name}")
            print(f"    Description: {description}")
            print(f"    Links: {link_count}")
            print()

    return 0

def list_tags(args):
    """List all tags in the XML file."""
    xml_path = get_xml_path()
    if not os.path.exists(xml_path):
        print(f"Error: XML file not found at {xml_path}")
        return 1

    # Parse the XML file
    tree = ET.parse(xml_path)
    root = tree.getroot()

    print("Available tags:")
    for tag in root.findall('.//tag'):
        tag_name = tag.get('name')
        link_count = len(tag.findall('link_ref'))
        print(f"  - {tag_name} ({link_count} links)")

    return 0

def format_xml_file(xml_path):
    """Format the XML file with proper indentation."""
    try:
        import xml.dom.minidom
        with open(xml_path, 'r', encoding='utf-8') as f:
            xml_content = f.read()

        dom = xml.dom.minidom.parseString(xml_content)
        pretty_xml = dom.toprettyxml(indent='  ')

        # Remove extra blank lines that minidom sometimes adds
        pretty_xml = '\n'.join([line for line in pretty_xml.split('\n') if line.strip()])

        with open(xml_path, 'w', encoding='utf-8') as f:
            f.write(pretty_xml)
    except Exception as e:
        print(f"Warning: Could not format XML file: {e}")

def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(description='Docker Documentation XML Updater')
    subparsers = parser.add_subparsers(dest='command', help='Command to execute')

    # add command
    add_parser = subparsers.add_parser('add', help='Add a new documentation link')
    add_parser.add_argument('--id', required=True, help='Unique identifier for the link')
    add_parser.add_argument('--category', required=True, help='Category ID to add the link to')
    add_parser.add_argument('--url', required=True, help='URL of the documentation')
    add_parser.add_argument('--title', required=True, help='Title of the documentation')
    add_parser.add_argument('--description', required=True, help='Description of the documentation')
    add_parser.add_argument('--tags', help='Comma-separated list of tags for the link')

    # list command
    list_parser = subparsers.add_parser('list', help='List documentation resources')
    list_parser.add_argument('--category', help='List links in the specified category')
    list_parser.add_argument('--tag', help='List links with the specified tag')

    # list-tags command
    list_tags_parser = subparsers.add_parser('list-tags', help='List all available tags')

    # Parse arguments
    args = parser.parse_args()

    if args.command == 'add':
        return add_link(args)
    elif args.command == 'list':
        return list_resources(args)
    elif args.command == 'list-tags':
        return list_tags(args)
    else:
        parser.print_help()
        return 0

if __name__ == '__main__':
    sys.exit(main())