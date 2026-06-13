namespace In2U.Api.Entities;

public class ChatMessage
{
    public long Id { get; set; }
    public Guid MessageGuid { get; set; } = Guid.NewGuid();
    public long MatchId { get; set; }
    public long FromUserId { get; set; }
    public string Body { get; set; } = string.Empty;
    public DateTime SentAt { get; set; } = DateTime.UtcNow;
    public DateTime? ReadAt { get; set; }
    public string? ClientMsgId { get; set; }
}
