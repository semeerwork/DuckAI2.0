/* worker.js refactored to support POST-only API with inline comments */

// Available model options
const MODELS = [
  'gpt-4o-mini',
  'o3-mini',
  'claude-3-haiku-20240307',
  'meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo',
  'mistralai/Mixtral-8x7B-Instruct-v0.1'
];

// Default model if none specified
const MAIN_MODEL = 'gpt-4o-mini';

// External endpoints for token retrieval and chatting
const STATUS_URL = 'https://duckduckgo.com/duckchat/v1/status';
const CHAT_API = 'https://duckduckgo.com/duckchat/v1/chat';

// Predefined error payload for 404 Not Found
const ERROR_404 = {
  action: 'error',
  status: 404,
  usage: 'POST /chat/ { prompt: <text>, model?: <model>, history?: <List[Dict]> }',
  models: MODELS
};

// Predefined error payload for invalid history format
const ERROR_403 = {
  action: 'error',
  status: 403,
  response: 'Wrong history syntax',
  example: "[{\"role\":\"user\",\"content\":\"Your text here\"}]"
};

// Common headers for JSON responses
const HEAD_JSON = {
  'content-type': 'application/json',
  'Access-Control-Allow-Origin': '*'
};

// Main event listener for handling all incoming HTTP requests
addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request));
});

// Handles the incoming request
async function handleRequest(request) {
  const url = new URL(request.url);

  // Only accept POST requests to /chat/ endpoint
  if ((url.pathname === '/duckchat/v1/chat' || url.pathname === '/chat/') && request.method === 'POST') {
    try {
      const { prompt, history = '[]', model = MAIN_MODEL } = await request.json();
      const response = await Chat(prompt, history, model);
      return new Response(JSON.stringify(response), { headers: HEAD_JSON });
    } catch (e) {
      // Catch parsing errors or missing fields
      return new Response(JSON.stringify(ERROR_403), { headers: HEAD_JSON });
    }
  }

  // If the endpoint is not matched, return 404
  return new Response(JSON.stringify(ERROR_404), { headers: HEAD_JSON });
}

// Handles communication with DuckDuckGo's Chat API
async function Chat(prompt, history, model) {
  // Fetch session tokens needed for the API call
  const statusResp = await fetch(STATUS_URL, { cache: 'no-store' });
  const headers = {
    'User-Agent': 'Mozilla/5.0',
    'Accept': '*/*',
    'Content-Type': 'application/json',
    'Referer': 'https://duckduckgo.com/',
    'x-vqd-4': statusResp.headers.get('x-vqd-4'),
    'x-vqd-hash-1': statusResp.headers.get('x-vqd-hash-1')
  };

  let messages;
  try {
    // Parse history JSON
    messages = JSON.parse(history);
  } catch {
    // Return an error if history format is invalid
    return ERROR_403;
  }

  // Add the current user prompt to the conversation history
  messages.push({ role: 'user', content: prompt });

  // Send the message history to the chat API
  const chatResp = await fetch(CHAT_API, {
    method: 'POST',
    headers,
    body: JSON.stringify({ model, messages })
  });

  const responseText = await chatResp.text();

  // Process streamed chat API responses to extract the final reply
  const reply = responseText
    .split('\n')
    .filter(line => line.includes('message'))
    .map(line => JSON.parse(line.split('data: ')[1]).message)
    .join('');

  // Handle empty or error responses
  if (!reply) {
    return { action: 'error', status: chatResp.status, response: responseText };
  }

  // Return the successful reply
  return { action: 'success', status: 200, response: reply, model };
}
