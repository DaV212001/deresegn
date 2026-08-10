import pypandoc

input_file = "INSA_Documentation_Combined.md"
output_file = "INSA_Documentation_F2.docx"

try:
    pypandoc.convert_file(input_file, 'docx', outputfile=output_file)
    print("DOCX created successfully.")
except Exception as e:
    print(f"Error creating DOCX: {e}")
