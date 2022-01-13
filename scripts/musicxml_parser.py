import wave
import random
import struct
import sys
import zipfile
from xml.dom import minidom
import os
import glob
import shutil

step_to_int = {
    'A': 1,
    'B': 3,
    'C': 4,
    'D': 6,
    'E': 8,
    'F': 9,
    'G': 11
}

# Remove the temp directory from previous runs
if (os.path.isdir('temp/')):
    shutil.rmtree('temp/')

# Fetch the filepath to the compressed MusicXML file (.mxl)
musicxml_filepath = sys.argv[1]

# Fetch the filepath to the generated memory contents file
memory_contents_filepath = sys.argv[2]

# Unzip the compressed file to the temp directory
zip_ref = zipfile.ZipFile(musicxml_filepath, 'r')
zip_ref.extractall('temp/')
zip_ref.close()

# Fetch and parse the XML file in the temp directory
xml_filepath = glob.glob("temp/*.xml")
#print(xml_filepath)
xmldoc = minidom.parse(xml_filepath[0])

# Print the XML tree for debugging
#print(xmldoc.toprettyxml())

# For the first part in the sheet music
parts = xmldoc.getElementsByTagName('part')[0]

notes = []

# Loop through every measure and pull each note
for measure in parts.getElementsByTagName('measure'):
    print("measure %s" % (measure.getAttribute('number')))
    for note in measure.getElementsByTagName('note'):
        rest_check = note.getElementsByTagName('rest')
        if (len(rest_check) > 0):
            duration = int(note.getElementsByTagName('duration')[0].childNodes[0].nodeValue)
            print("\trest note, duration %d" % (duration))
            notes += [(0, 0, 0, duration)]
        else:
            note_pitch = note.getElementsByTagName('pitch').item(0)
            step = note_pitch.getElementsByTagName('step')[0].childNodes[0].nodeValue
            octave = int(note_pitch.getElementsByTagName('octave')[0].childNodes[0].nodeValue)
            alter = note_pitch.getElementsByTagName('alter')
            if (len(alter) > 0):
                alter = int(alter[0].childNodes[0].nodeValue)
            else:
                alter = 0
            duration = int(note.getElementsByTagName('duration')[0].childNodes[0].nodeValue)
            note_type = note.getElementsByTagName('type')[0].childNodes[0].nodeValue
            print("\tnote with step %s octave %d alter %d duration %d type %s" % (step, octave, alter, duration, note_type))
            notes += [(step, octave, alter, duration)]

note_list = []
for note in notes:
    if (note[0] == 0):
        note_list += [(0, note[3])]
    else:
        semitone_above_below_middle_C = step_to_int[note[0]] - step_to_int['C'] + note[2]
        if (step_to_int[note[0]] >= step_to_int['C']):
            note_number = semitone_above_below_middle_C + ((note[1] - 4) * 12)
        else:
            note_number = semitone_above_below_middle_C + ((note[1] - 3) * 12)
        note_number = note_number + 40
        frequency = (2 ** ((float(note_number) - 49.0)/12.0)) * 440.0
        note_list += [(int(frequency), note[3])]

print("note_list (frequency, duration)\n")
print(note_list)

# Translate each note to the equivalent frequency and to the individual half-periods of 32nd notes
with open(memory_contents_filepath, 'w') as memory_file:
    for note in note_list:
        if (note[0] == 0):
            for i in range(0, 4 * note[1]):
                memory_file.write(str(0) + "\n")
            continue
        # Write the note in terms of tone_switch_period (125 Mhz clock)
        for i in range(0, 4 * note[1]):
            memory_file.write(str(int(125e6/note[0]/2)) + "\n")
        # Write a note pause for each note corresponding to its duration
        for i in range(0, note[1]):
            memory_file.write(str(0) + "\n")

# Remove the temp directory from current run
if (os.path.isdir('temp/')):
    shutil.rmtree('temp/')
