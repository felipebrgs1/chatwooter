package controllers

import (
	"net/http"
	"strconv"

	"github.com/felipeborgaco/chatwooter/server/internal/models"
	"github.com/felipeborgaco/chatwooter/server/internal/views"
)

// Messages serve .../conversations/{conversation_id}/messages.
type Messages struct {
	Conversations Conversations
}

func (c Messages) Index(w http.ResponseWriter, r *http.Request) {
	item, ok := c.Conversations.load(w, r)
	if !ok {
		return
	}
	before, _ := strconv.ParseInt(r.URL.Query().Get("before"), 10, 32)
	msgs, err := c.Conversations.Conversations.Messages(r.Context(), item.AccountID, item.ID, int32(max(before, 0)))
	if err != nil {
		modelError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.MessagesIndex(item, msgs))
}

func (c Messages) Create(w http.ResponseWriter, r *http.Request) {
	item, ok := c.Conversations.load(w, r)
	if !ok {
		return
	}
	var in struct {
		Content string `json:"content"`
		Private bool   `json:"private"`
		EchoID  string `json:"echo_id"`
	}
	if !decode(w, r, &in) {
		return
	}
	msg, err := c.Conversations.Conversations.CreateMessage(r.Context(), item.AccountID, item.ID, models.NewMessage{
		SenderID: CurrentUser(r).ID, Content: in.Content, Private: in.Private, EchoID: in.EchoID,
	})
	if err != nil {
		modelError(w, err)
		return
	}
	views.JSON(w, http.StatusOK, views.Message(msg))
}
