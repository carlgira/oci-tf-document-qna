import os
from hf_langchain import OpenSearchBackend
import gradio as gr

file_name = None
OPENSEARCH_URL = os.environ['OPENSEARCH_URL']

backed = OpenSearchBackend(OPENSEARCH_URL)

indexes = ["all"]

def upload_document_and_create_text_bindings(file):
    global file_name
    file_name = file.name.split('/')[-1]
    file_path = file.name

    docs = backed.read_document(file_path)
    backed.load_doc_to_db(docs, opensearch_index="hf_all", verify_certs=False)

    return 'file-loaded.txt'


def analyze_question(question, index):
    index_name = 'hf_' + index
    return backed.answer_query(question, opensearch_index=index_name, verify_certs=False)

with gr.Blocks(title='Document QA with Falcon 7B and Opensearch') as demo:
    gr.Markdown("# Document QA with Falcon 7B and Opensearch")
    gr.Markdown("This demo uses the Falcon-7b model to create text embeddings for a document and then uses these embeddings to find similar documents.")
    with gr.Row():
        with gr.Column():
            gr.Markdown("Upload a document (pdf, docx or txt). Wait for the document to be processed, if the document is long it could take a couple of minutes")
            gr.Markdown("By default the documents are uploaded to 'all' index")
            file_upload = gr.File()
            upload_button = gr.UploadButton("Select Document", file_types=["txt", "pdf", "docx"])
            upload_button.upload(upload_document_and_create_text_bindings, upload_button, file_upload)
        with gr.Column():
            gr.Markdown("First select the specific index, and ask question")
            dropdown = gr.Dropdown(indexes, value="all", label="Opensearch Index")
            chatbot = gr.Chatbot()
            msg = gr.Textbox()
            clear = gr.Button("Clear")

    def user(user_message, index, history):
        answer = analyze_question(user_message, index)
        return "", history + [[user_message, answer]]

    def bot(history):
        return history

    msg.submit(user, [msg, dropdown, chatbot], [msg, chatbot], queue=False).then(
        bot, chatbot, chatbot
    )

    clear.click(lambda: None, None, chatbot, queue=False)

demo.launch(server_name="0.0.0.0")
